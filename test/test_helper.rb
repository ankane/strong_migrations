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

TestMigration = activerecord5? ? ActiveRecord::Migration[migration_version] : ActiveRecord::Migration
TestSchema = ActiveRecord::Schema

class CreateUsers < TestMigration
  def change
    # needed for force: :cascade
    safety_assured do
      create_table "users", force: :cascade do |t|
        t.string :name
      end
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
