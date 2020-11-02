require_relative "test_helper"

class MiscTest < Minitest::Test
  def test_add_column_json
    skip unless postgresql?
    assert_unsafe AddColumnJson
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

  def test_create_table_force
    assert_unsafe CreateTableForce
  end

  def test_custom
    assert_unsafe Custom, "Cannot add forbidden column"
  end
end
