require_relative 'test_helper'

class CreateTableTest < Minitest::Test
  def test_create_table_with_integer
    assert_unsafe CreateTableWithInteger
  end

  def test_col_definition_in_safe_block
    assert_safe CreateTableWithSafetyAssured
  end

  def test_create_table_with_integer_column_call
    assert_unsafe CreateTableWithIntegerColumnCall
  end
end
