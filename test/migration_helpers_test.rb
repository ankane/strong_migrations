require_relative "test_helper"

class AddForeignKeySafely < TestMigration
  disable_ddl_transaction!

  def change
    add_foreign_key_safely :users, :orders
  end
end

class AddForeignKeySafelyTransaction < TestMigration
  def change
    add_foreign_key_safely :users, :orders
  end
end

class MigrationHelpersTest < Minitest::Test
  def test_add_foreign_key_safely
    skip unless postgres?

    migrate(AddForeignKeySafely)

    foreign_keys = connection.foreign_keys("users")
    assert_equal 1, foreign_keys.size

    fk = foreign_keys.first
    assert_equal "users", fk.from_table
    assert_equal "orders", fk.to_table
    assert_equal "order_id", fk.column
    assert_equal "id", fk.primary_key
    assert_equal "fk_rails_c1e9b98e31", fk.name

    migrate(AddForeignKeySafely, direction: :down)
  end

  def test_add_foreign_key_safely_raises_inside_transaction
    skip unless postgres?
    error = assert_raises(StrongMigrations::Error) { migrate_inside_transaction(AddForeignKeySafelyTransaction) }
    assert_match "Cannot run `add_foreign_key_safely` inside a transaction", error.message
  end

  def test_add_foreign_key_safely_raises_for_non_postgres
    skip if postgres?
    error = assert_raises(StrongMigrations::Error) { migrate(AddForeignKeySafely) }
    assert_match "Postgres only", error.message
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  # Emulate running migration using `rake db:migrate`
  def migrate_inside_transaction(migration)
    ActiveRecord::Base.transaction do
      migrate(migration)
    end
  end
end
