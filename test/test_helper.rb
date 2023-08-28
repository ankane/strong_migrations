require "bundler/setup"
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
  if ActiveRecord::VERSION::STRING.to_f >= 7.1
    connection_options[:prepared_statements] = true
  end
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
    ActiveRecord::Base.connection.schema_migration
  else
    ActiveRecord::SchemaMigration
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
    t.string :forbidden
  end
end

class User < ActiveRecord::Base
end

module Helpers
  def postgresql?
    $adapter == "postgresql"
  end

  def mysql?
    $adapter == "mysql2" && !ActiveRecord::Base.connection.mariadb?
  end

  def mariadb?
    $adapter == "mysql2" && ActiveRecord::Base.connection.mariadb?
  end
end

class Minitest::Test
  include Helpers

  def migrate(migration, direction: :up)
    if ActiveRecord::VERSION::STRING.to_f >= 7.1
      schema_migration.delete_all_versions
    else
      schema_migration.delete_all
    end
    migration = migration.new unless migration.is_a?(TestMigration)
    migration.version ||= 20170101000001
    if direction == :down
      if ActiveRecord::VERSION::STRING.to_f >= 7.1
        schema_migration.create_version(migration.version)
      else
        schema_migration.create!(version: migration.version)
      end
    end
    args =
      if ActiveRecord::VERSION::STRING.to_f >= 7.1
        [schema_migration, ActiveRecord::Base.connection.internal_metadata]
      elsif ActiveRecord::VERSION::MAJOR >= 6
        [schema_migration]
      else
        []
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

  def assert_safe(migration, direction: nil)
    if direction
      assert migrate(migration, direction: direction)
    else
      assert migrate(migration, direction: :up)
      assert migrate(migration, direction: :down)
    end
  end

  def assert_argument_error(migration)
    assert_raises(ArgumentError) do
      migrate(migration)
    end
  end

  def assert_type_error(migration)
    assert_raises(TypeError) do
      migrate(migration)
    end
  end

  def with_target_version(version)
    StrongMigrations.target_version = version
    yield
  ensure
    StrongMigrations.target_version = nil
  end

  def outside_developer_env
    StrongMigrations.stub(:developer_env?, false) do
      yield
    end
  end

  def check_constraints?
    ActiveRecord::VERSION::STRING.to_f >= 6.1
  end
end

StrongMigrations.add_check(:add_column, start_after: 20170101000000) do |method, args|
  if args[1].to_s == "forbidden"
    stop! "Cannot add forbidden column"
  end
end

Dir.glob("migrations/*.rb", base: __dir__).sort.each do |file|
  require_relative file
end
