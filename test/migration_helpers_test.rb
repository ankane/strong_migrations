require_relative "test_helper"

class AddForeignKeyConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    add_foreign_key_concurrently :users, :orders
  end
end

class MigrationHelpersTest < Minitest::Test
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_add_foreign_key_concurrently_raises_for_non_postgres
    skip if postgres?
    error = assert_raises(RuntimeError) { migrate(AddForeignKeyConcurrently) }
    assert_match "Postgres usage only", error.message
  end

  def test_add_foreign_key_concurrently_raises_inside_transaction
    skip unless postgres?
    migration = Class.new(TestMigration) do
      def change
        add_foreign_key_concurrently :users, :orders
      end
    end

    error = assert_raises(RuntimeError) { migrate_inside_transaction(migration) }
    assert_match "Cannot run `add_foreign_key_concurrently` inside a transaction", error.message
  end

  def test_add_foreign_key_concurrently
    skip unless postgres?
    migrate(AddForeignKeyConcurrently)

    foreign_keys = @connection.foreign_keys("users")
    assert_equal 1, foreign_keys.size

    fk = foreign_keys.first
    assert_equal "users", fk.from_table
    assert_equal "orders", fk.to_table
    assert_equal "order_id", fk.column
    assert_equal "id", fk.primary_key
    assert_equal "fk_rails_c1e9b98e31", fk.name
  ensure
    migrate(AddForeignKeyConcurrently, direction: :down) if postgres?
  end

  private

  # Emulate running migration using `rake db:migrate`
  def migrate_inside_transaction(migration)
    ActiveRecord::Base.transaction do
      migrate(migration)
    end
  end
end
