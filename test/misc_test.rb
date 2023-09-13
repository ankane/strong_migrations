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
end
