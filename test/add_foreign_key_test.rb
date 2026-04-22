require_relative "test_helper"

class AddForeignKeyTest < Minitest::Test
  def test_basic
    assert_unsafe AddForeignKey
  end

  def test_safe
    skip unless postgresql?

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
    assert_unsafe AddForeignKeyExtraArguments
  end
end
