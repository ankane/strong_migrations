require_relative "test_helper"

class AddForeignKeyTest < Minitest::Test
  def test_basic
    if postgresql?
      assert_unsafe AddForeignKey
    else
      assert_safe AddForeignKey
    end
  end

  def test_safe
    assert_safe AddForeignKeySafe
  end

  def test_validate_same_transaction
    skip unless postgresql?

    assert_unsafe AddForeignKeyValidateSameTransaction
  end

  def test_validate_no_transaction
    skip unless postgresql?

    assert_safe AddForeignKeyValidateNoTransaction
  end

  def test_extra_arguments
    if postgresql?
      assert_unsafe AddForeignKeyExtraArguments
    else
      assert_argument_error AddForeignKeyExtraArguments
    end
  end
end
