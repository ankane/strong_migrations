require_relative "test_helper"

class AddForeignKeyTest < Minitest::Test
  def test_add_foreign_key
    if postgresql?
      assert_unsafe AddForeignKey
    else
      assert_safe AddForeignKey
    end
  end

  def test_add_foreign_key_safe
    skip "Active Record 6.0.3 bug" if ar_bug? && (mysql? || mariadb?)

    assert_safe AddForeignKeySafe
  end

  def test_add_foreign_key_validate_same_transaction
    skip "Active Record 6.0.3 bug" if ar_bug?

    skip unless postgresql?

    assert_unsafe AddForeignKeyValidateSameTransaction
  end

  def test_add_foreign_key_validate_no_transaction
    skip "Active Record 6.0.3 bug" if ar_bug?

    skip unless postgresql?

    assert_safe AddForeignKeyValidateNoTransaction
  end

  def ar_bug?
    ActiveRecord::VERSION::STRING.start_with?("6.0.3")
  end
end
