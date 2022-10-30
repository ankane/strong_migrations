require_relative "test_helper"

class AddExclusionConstraintTest < Minitest::Test
  def setup
    skip unless exclusion_constraints?
    super
  end

  def test_basic
    assert_unsafe AddExclusionConstraint
  end

  def test_new_table
    assert_safe AddExclusionConstraintNewTable
  end

  def exclusion_constraints?
    postgresql? && ActiveRecord::VERSION::STRING.to_f >= 7.1
  end
end
