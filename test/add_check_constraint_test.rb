require_relative "test_helper"

class CheckConstraintTest < Minitest::Test
  def setup
    skip unless check_constraints?
    super
  end

  def test_add_check_constraint_without_enabled_tables
    without_enabled_tables do
      assert_safe AddCheckConstraint
    end
  end

  def test_add_check_constraint
    assert_unsafe AddCheckConstraint
  end

  def test_add_check_constraint_safe
    if postgresql?
      assert_safe AddCheckConstraintSafe
    else
      assert_unsafe AddCheckConstraintSafe
    end
  end

  def test_add_check_constraint_validate_same_transaction
    assert_unsafe AddCheckConstraintValidateSameTransaction
  end

  def test_add_check_constraint_validate_no_transaction
    if postgresql?
      assert_safe AddCheckConstraintValidateNoTransaction
    else
      assert_unsafe AddCheckConstraintValidateNoTransaction
    end
  end

  def test_add_check_constraint_new_table
    assert_safe AddCheckConstraintNewTable
  end

  def test_add_check_constraint_name
    assert_unsafe AddCheckConstraintName
  end
end
