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

def migrate(migration, direction: :up, transaction: nil)
  transaction = !migration.disable_ddl_transaction if transaction.nil?
  ActiveRecord::Migration.suppress_messages do
    if transaction
      ActiveRecord::Base.transaction { migration.migrate(direction) }
    else
      migration.migrate(direction)
    end
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
end

Minitest::Test.include(Helpers)

StrongMigrations.add_check do |method, args|
  if method == :add_column && args[1].to_s == "forbidden"
    stop! "Cannot add forbidden column"
  end
end

StrongMigrations.auto_analyze = true

StrongMigrations.enable_helpers if ENV["HELPERS"]
