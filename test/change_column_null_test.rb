require_relative "test_helper"

class ChangeColumnNullTest < Minitest::Test
  def test_basic
    if postgresql?
      assert_unsafe ChangeColumnNull
    elsif mysql?
      with_target_version("5.6.0") do
        assert_safe ChangeColumnNull
      end
    elsif mariadb?
      with_target_version("10.0.0") do
        assert_safe ChangeColumnNull
      end
    end
  end

  def test_old_mysql
    skip unless mysql? || mariadb?

    with_target_version("5.5.0") do
      assert_unsafe ChangeColumnNull
    end
  end

  def test_constraint
    skip unless postgresql?

    with_target_version(12) do
      assert_safe ChangeColumnNullConstraint
    end
  end

  def test_constraint_unvalidated
    skip unless postgresql?

    with_target_version(12) do
      assert_unsafe ChangeColumnNullConstraintUnvalidated
    end
  end

  def test_constraint_default
    skip unless postgresql?

    with_target_version(12) do
      assert_unsafe ChangeColumnNullConstraintDefault
    end
  end

  def test_constraint_before_12
    skip unless postgresql?

    with_target_version(11) do
      assert_unsafe ChangeColumnNullConstraint
    end
  end

  def test_default
    if postgresql?
      assert_unsafe ChangeColumnNullDefault
    elsif mysql?
      with_target_version("5.6.0") do
        assert_unsafe ChangeColumnNullDefault
      end
    elsif mariadb?
      with_target_version("10.0.0") do
        assert_unsafe ChangeColumnNullDefault
      end
    end
  end

  def test_constraint_methods
    skip unless postgresql? && check_constraints?

    with_target_version(12) do
      assert_safe ChangeColumnNullConstraintMethods
    end
  end

  def test_quoted
    skip unless postgresql?

    with_target_version(12) do
      assert_safe ChangeColumnNullQuoted
    end
  end

  def test_mysql_non_strict_mode
    skip unless mysql? || mariadb?

    without_strict_mode do
      with_target_version(mysql? ? "5.6.0" : "10.0.0") do
        assert_unsafe ChangeColumnNull
      end
    end
  end

  def without_strict_mode
    StrongMigrations.stub(:target_sql_mode, "") do
      yield
    end
  end
end
