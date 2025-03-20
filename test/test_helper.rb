require "bundler/setup"
require "logger" # for Active Support < 7.1
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"

# needed for target_version
module Rails
  def self.env
    ActiveSupport::StringInquirer.new("test")
  end
end

$adapter = ENV["ADAPTER"] || "postgresql"
connection_options = {
  adapter: $adapter,
  database: "strong_migrations_test"
}
if $adapter == "mysql2"
  connection_options[:encoding] = "utf8mb4"
  if ActiveRecord::VERSION::STRING.to_f >= 7.1 && ActiveRecord::VERSION::MAJOR < 8
    connection_options[:prepared_statements] = true
  end
elsif $adapter == "trilogy"
  if ActiveRecord::VERSION::STRING.to_f < 7.1
    require "trilogy_adapter/connection"
    ActiveRecord::Base.public_send :extend, TrilogyAdapter::Connection
  end
  connection_options[:host] = "127.0.0.1"
end
ActiveRecord::Base.establish_connection(**connection_options)

if ENV["VERBOSE"]
  ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
else
  ActiveRecord::Migration.verbose = false
end

def migration_version
  ActiveRecord.version.to_s.to_f
end

TestMigration = ActiveRecord::Migration[migration_version]
TestSchema = ActiveRecord::Schema

def schema_migration
  if ActiveRecord::VERSION::STRING.to_f >= 7.1
    connection_class.schema_migration
  else
    ActiveRecord::SchemaMigration
  end
end

def connection_class
  if ActiveRecord::VERSION::STRING.to_f >= 7.2
    ActiveRecord::Base.connection_pool
  else
    ActiveRecord::Base.connection
  end
end

schema_migration.create_table

ActiveRecord::Schema.define do
  if $adapter == "postgresql"
    # for change column
    enable_extension "citext"

    # for exclusion constraints
    enable_extension "btree_gist"

    # for gen_random_uuid() in Postgres < 13
    enable_extension "pgcrypto"
  end

  [:users, :new_users, :orders, :devices, :cities_users].each do |table|
    drop_table(table) if table_exists?(table)
  end

  create_table :users do |t|
    t.string :name
    t.string :city
    t.decimal :credit_score, precision: 10, scale: 5
    t.timestamp :deleted_at
    t.string :country, limit: 20
    t.string :interval
    t.text :description
    t.citext :code if $adapter == "postgresql"
    t.references :order
  end

  create_table :orders do |t|
  end

  create_table :devices do |t|
  end
end

class User < ActiveRecord::Base
end

module Helpers
  def postgresql?
    $adapter == "postgresql"
  end

  def mysql?
    ($adapter == "mysql2" || $adapter == "trilogy") && !ActiveRecord::Base.connection.mariadb?
  end

  def mariadb?
    ($adapter == "mysql2" || $adapter == "trilogy") && ActiveRecord::Base.connection.mariadb?
  end
end

class Minitest::Test
  include Helpers

  def migrate(migration, direction: :up, version: 123)
    if ActiveRecord::VERSION::STRING.to_f >= 7.1
      schema_migration.delete_all_versions
    else
      schema_migration.delete_all
    end
    migration = migration.new unless migration.is_a?(TestMigration)
    migration.version ||= version
    if direction == :down
      if ActiveRecord::VERSION::STRING.to_f >= 7.1
        schema_migration.create_version(migration.version)
      else
        schema_migration.create!(version: migration.version)
      end
    end
    args =
      if ActiveRecord::VERSION::STRING.to_f >= 7.1
        [schema_migration, connection_class.internal_metadata]
      else
        [schema_migration]
      end
    ActiveRecord::Migrator.new(direction, [migration], *args).migrate
    true
  rescue => e
    raise e.cause if e.cause
    raise e
  end

  def assert_unsafe(migration, message = nil, **options)
    error = assert_raises(StrongMigrations::UnsafeMigration) do
      migrate(migration, **options)
    end
    puts error.message if ENV["VERBOSE"]
    assert_match message, error.message if message
  end

  def assert_safe(migration, direction: nil, **options)
    if direction
      assert migrate(migration, direction: direction, **options)
    else
      assert migrate(migration, direction: :up, **options)
      assert migrate(migration, direction: :down, **options)
    end
  end

  def assert_argument_error(migration)
    assert_raises(ArgumentError) do
      migrate(migration)
    end
  end

  def with_start_after(start_after)
    StrongMigrations.stub(:start_after, start_after) do
      yield
    end
  end

  def with_target_version(version)
    StrongMigrations.target_version = version
    yield
  ensure
    StrongMigrations.target_version = nil
  end

  def with_safety_assured
    StrongMigrations::Checker.stub(:safe, true) do
      yield
    end
  end

  def outside_developer_env
    StrongMigrations.stub(:developer_env?, false) do
      yield
    end
  end

  def with_lock_timeout(lock_timeout)
    StrongMigrations.lock_timeout = lock_timeout
    yield
  ensure
    StrongMigrations.lock_timeout = nil
    ActiveRecord::Base.connection.execute("RESET lock_timeout")
  end

  def with_locked_table(table)
    pool = ActiveRecord::Base.connection_pool
    connection = pool.checkout

    if postgresql?
      connection.transaction do
        connection.execute("LOCK TABLE #{connection.quote_table_name(table)} IN ROW EXCLUSIVE MODE")
        yield
      end
    else
      begin
        connection.execute("LOCK TABLE #{connection.quote_table_name(table)} WRITE")
        yield
      ensure
        connection.execute("UNLOCK TABLES")
      end
    end
  ensure
    pool.checkin(connection) if connection
  end
end

StrongMigrations.add_check do |method, args|
  if method == :add_column && args[1].to_s == "forbidden"
    stop! "Cannot add forbidden column"
  end
end

Dir.glob("migrations/*.rb", base: __dir__).sort.each do |file|
  require_relative file
end
