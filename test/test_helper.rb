require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"

Minitest::Test = Minitest::Unit::TestCase unless defined?(Minitest::Test)

adapter = ENV["ADAPTER"] || "postgres"
ActiveRecord::Base.establish_connection("#{adapter}://localhost/strong_migrations_test")

StrongMigrations.start_after = 20170101000000

ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout) if ENV["VERBOSE"]

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

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS users")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS new_users")

class CreateUsers < TestMigration
  def change
    create_table "users" do |t|
      t.string :name
    end
  end
end
migrate CreateUsers

class Minitest::Test
  def postgres?
    ENV["ADAPTER"].nil?
  end
end

StrongMigrations.add_check do |method, args|
  if method == :add_foreign_key
    unsafe! "No foreign keys"
  end
end
