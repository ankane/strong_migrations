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

adapter = ENV["ADAPTER"] || "postgres"
ActiveRecord::Base.establish_connection("#{adapter}://localhost/strong_migrations_test")

if ENV["VERBOSE"]
  ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
else
  ActiveRecord::Migration.verbose = false
end

def migrate(migration, direction: :up)
  if !migration.disable_ddl_transaction
    ActiveRecord::Base.transaction { migration.migrate(direction) }
  else
    migration.migrate(direction)
  end
  true
end

def migration_version
  ActiveRecord.version.to_s.to_f
end

TestMigration = ActiveRecord::Migration[migration_version]
TestSchema = ActiveRecord::Schema

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS users")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS new_users")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS orders")

class CreateUsers < TestMigration
  def change
    create_table "users" do |t|
      t.string :name
      t.string :city
      t.decimal :credit_score, precision: 10, scale: 5
      t.timestamp :deleted_at
      t.string :country, limit: 20
      t.references :order
    end

    create_table "orders" do |t|
    end
  end
end
migrate CreateUsers

module Helpers
  def postgresql?
    ENV["ADAPTER"].nil?
  end

  def mysql?
    ENV["ADAPTER"] == "mysql2" && !ActiveRecord::Base.connection.try(:mariadb?)
  end

  def mariadb?
    ENV["ADAPTER"] == "mysql2" && ActiveRecord::Base.connection.try(:mariadb?)
  end

  def assert_unsafe(migration, message = nil, **options)
    error = assert_raises(StrongMigrations::UnsafeMigration) { migrate(migration, **options) }
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

  def with_target_version(version)
    StrongMigrations.target_version = version
    yield
  ensure
    StrongMigrations.target_version = nil
  end
end

Minitest::Test.include(Helpers)

StrongMigrations.add_check do |method, args|
  if method == :add_column && args[1].to_s == "forbidden"
    stop! "Cannot add forbidden column"
  end
end

require_relative "migrations"
