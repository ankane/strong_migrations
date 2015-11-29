require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

Minitest::Test = Minitest::Unit::TestCase unless defined?(Minitest::Test)

adapter = ENV["ADAPTER"] || "postgres"
ActiveRecord::Base.establish_connection("#{adapter}://localhost/strong_migrations_test")

def migrate(migration)
  ActiveRecord::Migration.suppress_messages do
    migration.migrate(:up)
  end
  true
end

class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table "users", force: :cascade do |t|
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
