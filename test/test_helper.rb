require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

Minitest::Test = Minitest::Unit::TestCase unless defined?(Minitest::Test)

adapter = ENV["ADAPTER"] || "postgres"
ActiveRecord::Base.establish_connection("#{adapter}://localhost/strong_migrations_test")

# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)

def migrate(migration, direction: :up)
  ActiveRecord::Migration.suppress_messages do
    migration.migrate(direction)
  end
  true
end

def activerecord5?
  ActiveRecord::VERSION::MAJOR >= 5
end

def migration_version
  ActiveRecord.version.to_s.to_f
end

def with_safety_assumed_prior_to(version)
  previous_version = StrongMigrations.assume_safety_prior_to_version
  StrongMigrations.assume_safety_prior_to_version = version
  yield
ensure
  StrongMigrations.assume_safety_prior_to_version = previous_version
end

TestMigration = activerecord5? ? ActiveRecord::Migration[migration_version] : ActiveRecord::Migration
TestMigration.class_eval do
  def version
    20170515205830 # arbitrary for test cases
  end
end

TestSchema = ActiveRecord::Schema

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS users")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS new_users")

class CreateUsers < TestMigration
  def change
    create_table "users" do |t|
      t.string :name
    end
  end
end

class StrongMigrationsTestBase < Minitest::Test
  def postgres?
    ENV["ADAPTER"].nil?
  end

  # Create users table before each test and drop all tables
  # after each test so tests can execute independently.

  def setup
    migrate CreateUsers
  end

  def teardown
    conn = ActiveRecord::Base.connection
    tables = conn.tables
    tables.each do |table|
      conn.drop_table(table)
    end
  end
end
