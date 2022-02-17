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

  def test_custom
    assert_unsafe Custom, "Cannot add forbidden column"
  end

  # TODO raise error in 0.9.0
  def test_unsupported_version
    _, stderr = capture_io do
      with_target_version(1) do
        assert_unsafe ExecuteArbitrarySQL
      end
    end
    assert_match "version (1) not supported", stderr
  end
end
