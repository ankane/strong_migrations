require_relative "test_helper"

class StrongMigrationsTest < Minitest::Test
  def test_add_index
    if postgresql?
      assert_unsafe AddIndex, <<~EOF
        Adding an index non-concurrently locks the table. Instead, use:

        class AddIndex < ActiveRecord::Migration[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]
          disable_ddl_transaction!

          def change
            add_index :users, :name, algorithm: :concurrently
          end
        end
      EOF
    else
      assert_safe AddIndex
    end
  end

  def test_add_index_up
    if postgresql?
      assert_unsafe AddIndexUp
    else
      assert_safe AddIndexUp
    end
  end

  def test_add_index_safety_assured
    assert_safe AddIndexSafetyAssured
  end

  def test_add_index_new_table
    assert_safe AddIndexNewTable
  end

  def test_schema
    assert_safe AddIndexSchema
  end

  def test_add_index_concurrently
    skip unless postgresql?
    assert_safe AddIndexConcurrently
  end

  def test_remove_index_concurrently
    skip unless postgresql?
    migrate AddIndexConcurrently

    begin
      StrongMigrations.enable_check(:remove_index)
      assert_unsafe RemoveIndex
      migrate RemoveIndexConcurrently
    ensure
      StrongMigrations.disable_check(:remove_index)
    end
  end

  def test_add_column_default
    StrongMigrations.target_postgresql_version = "10"
    StrongMigrations.target_mysql_version = "8.0.11"
    StrongMigrations.target_mariadb_version = "10.3.1"
    assert_unsafe AddColumnDefault
  ensure
    StrongMigrations.target_postgresql_version = nil
    StrongMigrations.target_mysql_version = nil
    StrongMigrations.target_mariadb_version = nil
  end

  def test_add_column_default_safe_latest
    skip unless postgresql? || mysql? || mariadb?

    StrongMigrations.target_postgresql_version = "11"
    StrongMigrations.target_mysql_version = "8.0.12"
    StrongMigrations.target_mariadb_version = "10.3.2"
    assert_safe AddColumnDefault
  ensure
    StrongMigrations.target_postgresql_version = nil
    StrongMigrations.target_mysql_version = nil
    StrongMigrations.target_mariadb_version = nil
  end

  def test_add_column_default_safe
    assert_safe AddColumnDefaultSafe
  end

  def test_add_column_json
    skip unless postgresql?
    assert_unsafe AddColumnJson
  end

  def test_change_column
    assert_unsafe ChangeColumn
  end

  def test_change_column_varchar_to_text
    skip unless postgresql?
    assert_safe ChangeColumnVarcharToText
  end

  def test_change_column_decimal_decrease_precision
    skip unless postgresql?
    assert_unsafe ChangeColumnDecimalDecreasePrecision
  end

  def test_change_column_decimal_change_scale
    skip unless postgresql?
    assert_unsafe ChangeColumnDecimalChangeScale
  end

  def test_change_column_decimal_increase_precision
    skip unless postgresql?
    assert_safe ChangeColumnDecimalIncreasePrecision
  end

  def test_change_column_decimal_unconstrained
    skip unless postgresql?
    assert_safe ChangeColumnDecimalIncreasePrecision
  end

  def test_execute_arbitrary_sql
    assert_unsafe ExecuteArbitrarySQL
  end

  def test_rename_column
    assert_unsafe RenameColumn
  end

  def test_rename_table
    assert_unsafe RenameTable
  end

  def test_remove_column
    assert_unsafe RemoveColumn
  end

  def test_remove_columns
    assert_unsafe RemoveColumns
  end

  def test_remove_timestamps
    assert_unsafe RemoveTimestamps
  end

  def test_remove_reference
    assert_unsafe RemoveReference
  end

  def test_remove_reference_polymorphic
    assert_unsafe RemoveReferencePolymorphic
  end

  def test_remove_belongs_to
    assert_unsafe RemoveBelongsTo
  end

  def test_add_index_columns
    assert_unsafe AddIndexColumns, /more than three columns/
  end

  def test_add_index_columns_unique
    skip unless postgresql?
    assert_safe AddIndexColumnsUnique
  end

  def test_add_reference
    skip unless postgresql?
    assert_unsafe AddReference
  end

  def test_add_reference_polymorphic
    skip unless postgresql?
    assert_unsafe AddReferencePolymorphic
  end

  def test_add_reference_no_index
    skip unless postgresql?
    assert_safe AddReferenceNoIndex
  end

  def test_add_reference_default
    skip unless postgresql?
    assert_unsafe AddReferenceDefault
  end

  def test_add_reference_concurrently
    skip unless postgresql?
    assert_safe AddReferenceConcurrently
  end

  def test_add_belongs_to
    skip unless postgresql?
    assert_unsafe AddBelongsTo
  end

  def test_create_table_force
    assert_unsafe CreateTableForce
  end

  def test_version_safe
    with_start_after(20170101000000) do
      assert_safe VersionSafe
    end
  end

  def test_version_unsafe
    with_start_after(20170101000000) do
      assert_unsafe VersionUnsafe
    end
  end

  def test_change_column_null
    assert_unsafe ChangeColumnNull
  end

  def test_change_column_null_no_default
    if postgresql? || mysql? || mariadb?
      assert_unsafe ChangeColumnNullNoDefault
    else
      assert_safe ChangeColumnNullNoDefault
    end
  end

  def test_add_foreign_key
    if postgresql?
      assert_unsafe AddForeignKey
    else
      assert_safe AddForeignKey
    end
  end

  def test_add_foreign_key_safe
    if postgresql? && ActiveRecord::VERSION::STRING <= "5.2"
      assert_unsafe AddForeignKeySafe
    else
      assert_safe AddForeignKeySafe
    end
  end

  def test_custom
    assert_unsafe Custom, "Cannot add forbidden column"
  end

  def test_timeouts
    skip unless postgresql? || mysql? || mariadb?

    StrongMigrations.statement_timeout = 1.hour
    StrongMigrations.lock_timeout = 10.seconds

    migrate CheckTimeouts

    if postgresql?
      assert_equal "1h", $statement_timeout
      assert_equal "10s", $lock_timeout
    else
      assert_equal 3600, $statement_timeout
      assert_equal 10, $lock_timeout
    end
  ensure
    StrongMigrations.statement_timeout = nil
    StrongMigrations.lock_timeout = nil
  end

  private

  def with_start_after(start_after)
    previous = StrongMigrations.start_after
    begin
      StrongMigrations.start_after = start_after
      yield
    ensure
      StrongMigrations.start_after = previous
    end
  end

  def assert_unsafe(migration, message = nil)
    error = assert_raises(StrongMigrations::UnsafeMigration) { migrate(migration) }
    puts error.message if ENV["VERBOSE"]
    assert_match message, error.message if message
  end

  def assert_safe(migration)
    assert migrate(migration, direction: :up)
    assert migrate(migration, direction: :down)
  end
end
