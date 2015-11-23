require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

Minitest::Test = Minitest::Unit::TestCase unless defined?(Minitest::Test)

ActiveRecord::Base.establish_connection "postgres://localhost/strong_migrations_test"

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
