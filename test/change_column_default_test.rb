require_relative "test_helper"

class ChangeColumnDefaultTest < Minitest::Test
  def test_basic
    assert_unsafe ChangeColumnDefault
  end

  def test_hash
    assert_unsafe ChangeColumnDefaultHash
  end

  def test_new_column
    assert_safe ChangeColumnDefaultNewColumn
  end
end
