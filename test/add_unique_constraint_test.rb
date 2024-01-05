require_relative "test_helper"

class AddUniqueConstraintTest < Minitest::Test
  def setup
    skip unless unique_constraints?
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

  def unique_constraints?
    postgresql? && ActiveRecord::VERSION::STRING.to_f >= 7.1
  end
end
