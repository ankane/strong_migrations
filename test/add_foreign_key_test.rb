require_relative "test_helper"

class AddForeignKeyTest < Minitest::Test
  def test_add_foreign_key_without_enabled_tables
    without_enabled_tables do
      assert_safe AddForeignKey
    end
  end

  def test_add_foreign_key
    if postgresql?
      assert_unsafe AddForeignKey
    else
      assert_safe AddForeignKey
    end
  end

  def test_add_foreign_key_safe
    skip "Active Record 6.0.3 bug" if (mysql? || mariadb?) && ActiveRecord::VERSION::STRING.start_with?("6.0.3")

    if postgresql? && ActiveRecord::VERSION::STRING <= "5.2"
      assert_unsafe AddForeignKeySafe
    else
      assert_safe AddForeignKeySafe
    end
  end

  def test_add_foreign_key_validate_same_transaction
    skip "Active Record 6.0.3 bug" if ActiveRecord::VERSION::STRING.start_with?("6.0.3")

    skip unless postgresql? && ActiveRecord::VERSION::STRING >= "5.2"

    assert_unsafe AddForeignKeyValidateSameTransaction
  end

  def test_add_foreign_key_validate_no_transaction
    skip "Active Record 6.0.3 bug" if ActiveRecord::VERSION::STRING.start_with?("6.0.3")

    skip unless postgresql? && ActiveRecord::VERSION::STRING >= "5.2"

    assert_safe AddForeignKeyValidateNoTransaction
  end
end
