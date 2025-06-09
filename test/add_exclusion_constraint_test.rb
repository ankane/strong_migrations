require_relative "test_helper"

class AddExclusionConstraintTest < Minitest::Test
  def setup
    skip unless postgresql?
    super
  end

  def test_basic
    assert_unsafe AddExclusionConstraint
  end

  def test_new_table
    assert_safe AddExclusionConstraintNewTable
  end
end
