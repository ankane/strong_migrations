require_relative "test_helper"

class AddCheckConstraintTest < Minitest::Test
  def test_basic
    assert_unsafe AddCheckConstraint
  end

  def test_safe
    if postgresql?
      assert_safe AddCheckConstraintSafe
    else
      assert_unsafe AddCheckConstraintSafe
    end
  end

  def test_validate_same_transaction
    assert_unsafe AddCheckConstraintValidateSameTransaction
  end

  def test_validate_no_transaction
    if postgresql?
      assert_safe AddCheckConstraintValidateNoTransaction
    else
      assert_unsafe AddCheckConstraintValidateNoTransaction
    end
  end

  def test_new_table
    assert_safe AddCheckConstraintNewTable
  end

  def test_name
    assert_unsafe AddCheckConstraintName
  end

  def test_extra_arguments
    assert_unsafe AddCheckConstraintExtraArguments
  end
end
