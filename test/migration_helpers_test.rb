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

class AddMoneyToUsers < TestMigration
  def change
    safety_assured do
      add_column :users, :money, :decimal, limit: 4, default: 100.0, precision: 10, scale: 3, comment: "Balance in $"
      add_index :users, :money
    end
  end
end

class RenameColumnSafely < TestMigration
  def change
    rename_column_safely :users, :money, :balance
  end
end

class RenameColumnSafelyForeignKey < TestMigration
  def change
    safety_assured { add_foreign_key :users, :orders }
    rename_column_safely :users, :order_id, :new_order_id
  end
end

class RenameColumnSafelyCleanup < TestMigration
  def change
    rename_column_safely_cleanup :users, :money, :balance
  end
end

class ChangeColumnSafely < TestMigration
  def up
    change_column_safely :users, :bio, :string, default: "No bio"
  end

  def down
    change_column_safely :users, :bio, :string, default: nil
  end
end

class ChangeColumnSafelyNonReversible < TestMigration
  def change
    change_column_safely :users, :bio, :string, default: "No bio"
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

  def test_rename_column_safely_raises_inside_transaction
    error = assert_raises(StrongMigrations::Error) { migrate_inside_transaction(RenameColumnSafely) }
    assert_match "Cannot run `rename_column_safely` inside a transaction", error.message
  end

  def test_rename_column_safely_copies_column
    migrate(AddMoneyToUsers)
    migrate(RenameColumnSafely)
    columns = connection.columns("users")
    old_column = columns.find { |c| c.name == "money" }
    new_column = columns.find { |c| c.name == "balance" }

    assert_equal old_column.type,       new_column.type
    assert_equal old_column.limit,      new_column.limit
    assert_equal old_column.default,    new_column.default
    assert_equal old_column.precision,  new_column.precision
    assert_equal old_column.scale,      new_column.scale
    assert_equal old_column.comment,    new_column.comment
  ensure
    migrate(RenameColumnSafely, direction: :down)
    migrate(AddMoneyToUsers, direction: :down)
  end

  def test_rename_column_safely_copies_foreign_keys
    migrate(RenameColumnSafelyForeignKey)
    assert connection.foreign_key_exists?(:users, column: :new_order_id)
  ensure
    migrate(RenameColumnSafelyForeignKey, direction: :down)
    refute connection.foreign_key_exists?(:users, column: :new_order_id)
  end

  def test_rename_column_safely_copies_column_indexes
    migrate(AddMoneyToUsers)
    migrate(RenameColumnSafely)
    assert connection.index_exists?(:users, :balance)
  ensure
    migrate(RenameColumnSafely, direction: :down)
    migrate(AddMoneyToUsers, direction: :down)
  end

  def test_rename_column_safely_copies_data_to_new_column
    User.reset_column_information
    migrate(AddMoneyToUsers)
    migrate(RenameColumnSafely)
    user = User.create(name: "Dima", city: "Kyiv", money: 10.0)
    assert_equal 10.0, user.reload.balance
  ensure
    User.delete_all
    migrate(RenameColumnSafely, direction: :down)
    migrate(AddMoneyToUsers, direction: :down)
  end

  def test_rename_column_safely_cleanup_removes_old_column
    migrate(AddMoneyToUsers)
    migrate(RenameColumnSafely)
    migrate(RenameColumnSafelyCleanup)

    assert_equal false, connection.column_exists?(:users, :money)
  ensure
    migrate(RenameColumnSafelyCleanup, direction: :down)
    migrate(RenameColumnSafely, direction: :down)
    migrate(AddMoneyToUsers, direction: :down)
  end

  def test_change_column_safely_raises_inside_transaction
    skip unless postgresql?
    error = assert_raises(StrongMigrations::Error) { migrate_inside_transaction(ChangeColumnSafely) }
    assert_match "Cannot run `change_column_safely` inside a transaction", error.message
  end

  def test_change_column_safely_is_not_reversible
    skip unless postgresql?
    migrate(ChangeColumnSafelyNonReversible)

    assert_raises(ActiveRecord::IrreversibleMigration) do
      migrate(ChangeColumnSafelyNonReversible, direction: :down)
    end
  end

  def test_change_column_safely
    skip unless postgresql?
    migrate(ChangeColumnSafely)
    column = column_for("users", "bio")
    assert_equal "No bio", column.default

    migrate(ChangeColumnSafely, direction: :down)
    column = column_for("users", "bio")
    assert_nil column.default
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

  def column_for(table, name)
    name = name.to_s
    connection.columns(table).find { |c| c.name == name }
  end
end
