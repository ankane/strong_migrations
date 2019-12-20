require_relative "test_helper"

class AddForeignKeySafely < TestMigration
  def change
    add_foreign_key_safely :users, :orders
  end
end

class AddNullConstraintSafely < TestMigration
  def change
    add_null_constraint_safely :users, :name
  end
end

class AddColumnSafely < TestMigration
  def change
    add_column_safely :users, :nice, :boolean, default: true, null: false
  end
end

class BackfillColumnSafely < TestMigration
  def up
    backfill_column_safely :users, :city, "Kyiv", batch_size: 1
  end
end

class MigrationHelpersTest < Minitest::Test
  def test_add_foreign_key_safely
    skip unless postgresql?

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
    skip unless postgresql?
    error = assert_raises(StrongMigrations::Error) { migrate_inside_transaction(AddForeignKeySafely) }
    assert_match "Cannot run `add_foreign_key_safely` inside a transaction", error.message
  end

  def test_add_foreign_key_safely_raises_for_non_postgres
    skip if postgresql?
    error = assert_raises(StrongMigrations::Error) { migrate(AddForeignKeySafely) }
    assert_match "Postgres only", error.message
  end

  def test_add_null_constraint_safely
    skip unless postgresql?

    migrate(AddNullConstraintSafely)
    migrate(AddNullConstraintSafely, direction: :down)
  end

  def test_add_column_safely_raises_inside_transaction
    skip unless postgresql?
    error = assert_raises(StrongMigrations::Error) { migrate_inside_transaction(AddColumnSafely) }
    assert_match "Cannot run `add_column_safely` inside a transaction", error.message
  end

  def test_add_foreign_key_safely_raises_for_non_postgres
    skip if postgresql?
    error = assert_raises(StrongMigrations::Error) { migrate(AddColumnSafely) }
    assert_match "is intended for Postgres", error.message
  end

  def test_add_column_safely
    skip unless postgresql?

    User.reset_column_information
    migrate(AddColumnSafely)

    column = User.columns.find { |c| c.name == "nice" }
    assert_equal :boolean, column.type
    assert_equal "true", column.default
    assert_equal false, column.null

    migrate(AddColumnSafely, direction: :down)
  ensure
    User.reset_column_information
  end

  def test_backfill_column_safely_raises_inside_transaction
    error = assert_raises(StrongMigrations::Error) { migrate_inside_transaction(BackfillColumnSafely) }
    assert_match "Cannot run `backfill_column_safely` inside a transaction", error.message
  end

  def test_backfill_column_safely
    User.create([{ name: "John", city: "San Francisco" }, { name: "Jane", city: "London" }])
    migrate(BackfillColumnSafely)
    users = User.all
    assert users.all? { |u| u.city == "Kyiv" }
  ensure
    User.delete_all
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
