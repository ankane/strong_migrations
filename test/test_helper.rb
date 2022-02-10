require 'bundler/setup'
Bundler.require(:default)
require 'minitest/autorun'
require 'minitest/pride'
require 'active_record'

# needed for target_version
module Rails
  def self.env
    ActiveSupport::StringInquirer.new('test')
  end
end

$adapter = ENV['ADAPTER'] || 'postgresql'
ActiveRecord::Base.establish_connection(adapter: $adapter, database: 'strong_migrations_test')

if ENV['VERBOSE']
  ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
else
  ActiveRecord::Migration.verbose = false
end

def migration_version
  ActiveRecord.version.to_s.to_f
end

def active_record_schema_class
  @active_record_schema_class ||= if Object.const_defined?('ActiveRecord::Schema::Definition')
                                    ActiveRecord::Schema
                                  else
                                    ActiveRecord::Schema[migration_version]
                                  end
end

TestMigration = ActiveRecord::Migration[migration_version]
TestSchema = active_record_schema_class

active_record_schema_class.define do
  %i[users new_users orders devices].each do |table|
    drop_table(table) if table_exists?(table)
  end

  create_table :users do |t|
    t.string :name
    t.string :city
    t.decimal :credit_score, precision: 10, scale: 5
    t.timestamp :deleted_at
    t.string :country, limit: 20
    t.string :interval
    t.references :order
  end

  create_table :orders do |t|
  end

  create_table :devices do |t|
  end
end

module Helpers
  def postgresql?
    $adapter == 'postgresql'
  end

  def mysql?
    $adapter == 'mysql2' && !ActiveRecord::Base.connection.mariadb?
  end

  def mariadb?
    $adapter == 'mysql2' && ActiveRecord::Base.connection.mariadb?
  end
end

class Minitest::Test
  include Helpers

  def migrate(migration, direction: :up)
    if !migration.disable_ddl_transaction
      ActiveRecord::Base.transaction do
        migration.migrate(direction)
      end
    else
      migration.migrate(direction)
    end
    puts "\n\n" if ENV['VERBOSE']
    true
  end

  def assert_unsafe(migration, message = nil, **options)
    error = assert_raises(StrongMigrations::UnsafeMigration) do
      migrate(migration, **options)
    end
    puts error.message if ENV['VERBOSE']
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

  def check_constraints?
    ActiveRecord::VERSION::STRING.to_f >= 6.1
  end
end

StrongMigrations.add_check do |method, args|
  stop! 'Cannot add forbidden column' if method == :add_column && args[1].to_s == 'forbidden'
end

Dir.glob('migrations/*.rb', base: __dir__).sort.each do |file|
  require_relative file
end
