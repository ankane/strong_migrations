require_relative "test_helper"

class AddExclusionConstraintTest < Minitest::Test
  def setup
    skip unless ActiveRecord::VERSION::STRING.to_f >= 7.1
    super
  end

  def test_basic
    assert_unsafe AddExclusionConstraint
  end

  def test_new_table
    assert_safe AddExclusionConstraintNewTable
  end
end
