require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"

# needed for target_postgresql_version
module Rails
  def self.env
    ActiveSupport::StringInquirer.new("test")
  end
end

adapter = ENV["ADAPTER"] || "postgres"
ActiveRecord::Base.establish_connection("#{adapter}://localhost/strong_migrations_test")

ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout) if ENV["VERBOSE"]

def migrate(migration, direction: :up)
  ActiveRecord::Migration.suppress_messages do
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
      t.references :order
    end

    create_table "orders" do |t|
    end
  end
end
migrate CreateUsers

class User < ActiveRecord::Base
end

class Minitest::Test
  def postgresql?
    ENV["ADAPTER"].nil?
  end
end

StrongMigrations.add_check do |method, args|
  if method == :add_column && args[1].to_s == "forbidden"
    stop! "Cannot add forbidden column"
  end
end

StrongMigrations.auto_analyze = true
