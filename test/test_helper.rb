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

class CreateUsers < ActiveRecord::Migration
  def change
    create_table "users", id: false, force: :cascade do |t|
      t.integer :id, limit: 8, primary_key: true
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
