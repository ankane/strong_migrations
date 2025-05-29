require_relative "test_helper"

class AddUniqueConstraintTest < Minitest::Test
  def setup
    skip unless postgresql?
    super
  end

  def test_basic
    assert_unsafe AddUniqueConstraint
  end

  def test_using_index
    assert_safe AddUniqueConstraintUsingIndex
  end

  def test_new_table
    assert_safe AddUniqueConstraintNewTable
  end
end
