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
    skip "Active Record 6.0.3 bug" if ar_bug? && (mysql? || mariadb?)

    assert_safe AddForeignKeySafe
  end

  def test_validate_same_transaction
    skip "Active Record 6.0.3 bug" if ar_bug?

    skip unless postgresql?

    assert_unsafe AddForeignKeyValidateSameTransaction
  end

  def test_validate_no_transaction
    skip "Active Record 6.0.3 bug" if ar_bug?

    skip unless postgresql?

    assert_safe AddForeignKeyValidateNoTransaction
  end

  def test_extra_arguments
    if postgresql?
      assert_unsafe AddForeignKeyExtraArguments
    elsif ActiveRecord::VERSION::MAJOR >= 6
      assert_argument_error AddForeignKeyExtraArguments
    else
      assert_type_error AddForeignKeyExtraArguments
    end
  end

  def ar_bug?
    ActiveRecord::VERSION::STRING.start_with?("6.0.3")
  end
end
