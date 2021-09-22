require_relative "test_helper"

class ChangeColumnNullTest < Minitest::Test
  def test_change_column_null_without_enabled_tables
    without_enabled_tables do
      assert_safe ChangeColumnNull
    end
  end

  def test_change_column_null
    if postgresql? || mysql? || mariadb?
      assert_unsafe ChangeColumnNull
    else
      assert_safe ChangeColumnNull
    end
  end

  def test_change_column_null_constraint
    skip unless postgresql?

    with_target_version(12) do
      assert_safe ChangeColumnNullConstraint
    end
  end

  def test_change_column_null_constraint_unvalidated
    skip unless postgresql?

    with_target_version(12) do
      assert_unsafe ChangeColumnNullConstraintUnvalidated
    end
  end

  def test_change_column_null_constraint_before_12
    skip unless postgresql?

    with_target_version(11) do
      assert_unsafe ChangeColumnNullConstraint
    end
  end

  def test_change_column_null_default
    assert_unsafe ChangeColumnNullDefault
  end

  def test_change_column_null_constraint_methods
    skip unless postgresql? && check_constraints?

    with_target_version(12) do
      assert_safe ChangeColumnNullConstraintMethods
    end
  end

  def test_change_column_null_quoted
    skip unless postgresql?

    with_target_version(12) do
      assert_safe ChangeColumnNullQuoted
    end
  end
end
