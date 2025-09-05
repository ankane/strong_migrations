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
  if ActiveRecord::VERSION::MAJOR < 8
    connection_options[:prepared_statements] = true
  end
elsif $adapter == "trilogy"
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
  connection_class.schema_migration
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
