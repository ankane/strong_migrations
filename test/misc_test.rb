require_relative "test_helper"

class MiscTest < Minitest::Test
  def test_execute_arbitrary_sql
    assert_unsafe ExecuteArbitrarySQL
  end

  def test_rename_column
    assert_unsafe RenameColumn
  end

  def test_rename_table
    assert_unsafe RenameTable
  end

  def test_create_table_force
    assert_unsafe CreateTableForce
  end

  def test_create_join_table
    assert_safe CreateJoinTable
  end

  def test_create_join_table_force
    assert_unsafe CreateJoinTableForce
  end

  def test_revert
    migrate AddReferenceNoIndex
    assert_unsafe RevertAddReference
    migrate RevertAddReferenceSafetyAssured
  end

  def test_revert_safe
    with_safety_assured do
      migrate CreateTableForce
    end
    migrate RevertCreateTableForce
  end

  def test_revert_down
    assert_unsafe RevertCreateTableForce, direction: :down
  end

  def test_revert_inline
    migrate AddReferenceNoIndex
    assert_unsafe RevertAddReference
    migrate RevertAddReferenceSafetyAssured
  end

  def test_revert_inline_safe
    with_safety_assured do
      migrate CreateTableForce
    end
    migrate RevertCreateTableForceInline
  end

  def test_custom
    assert_unsafe Custom, "Cannot add forbidden column"
  end

  def test_unsupported_version
    error = assert_raises(StrongMigrations::UnsupportedVersion) do
      with_target_version(1) do
        migrate ExecuteArbitrarySQL
      end
    end
    assert_match "version (1) not supported", error.message
  end

  def test_target_version_outside_developer_env
    outside_developer_env do
      with_target_version(1) do
        # ignores target version
        # (does not throw UnsupportedVersion error)
        assert_unsafe ExecuteArbitrarySQL
      end
    end
  end

  def test_unsupported_adapter
    previous_db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    schema_migration.create_table
    assert_output nil, /Unsupported adapter/ do
      assert_unsafe CreateTableForce
    end
  ensure
    ActiveRecord::Base.establish_connection(previous_db_config) if previous_db_config
  end
end
