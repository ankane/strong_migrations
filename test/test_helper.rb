require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

Minitest::Test = Minitest::Unit::TestCase unless defined?(Minitest::Test)

adapter = ENV["ADAPTER"] || "postgres"
ActiveRecord::Base.establish_connection("#{adapter}://localhost/strong_migrations_test")

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
    create_table "users", force: :cascade do |t|
      t.string :name
      t.timestamp :created_at
    end
  end
end
migrate CreateUsers

class User < ActiveRecord::Base
  self.ignored_columns = %w(created_at) if activerecord5?
end

class Minitest::Test
  def postgres?
    ENV["ADAPTER"].nil?
  end
end
