require_relative "test_helper"

class CheckConstraintTest < Minitest::Test
  def setup
    skip unless check_constraints?
    super
  end

  def test_add_check_constraint
    assert_unsafe AddCheckConstraint
  end

  def test_add_check_constraint_safe
    assert_safe AddCheckConstraintSafe
  end

  def test_add_check_constraint_validate_same_transaction
    assert_unsafe AddCheckConstraintValidateSameTransaction
  end

  def test_add_check_constraint_validate_no_transaction
    assert_safe AddCheckConstraintValidateNoTransaction
  end

  def test_add_check_constraint_new_table
    assert_safe AddCheckConstraintNewTable
  end

  def test_add_check_constraint_name
    assert_unsafe AddCheckConstraintName
  end
end
