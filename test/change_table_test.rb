require_relative "test_helper"

class ChangeTableTest < Minitest::Test
  def test_change_table
    assert_unsafe ChangeTable
  end

  def test_safe_change_table
    assert_safe SafeChangeTable
  end

  def test_safe_change_table_unsafe
    assert_unsafe SafeChangeTableUnsafe, "Active Record caches attributes"
  end

  def test_safe_change_table_does_not_apply_on_failure
    columns_before = User.columns_hash.keys
    assert_unsafe SafeChangeTableCustomCheck
    User.reset_column_information
    columns_after = User.columns_hash.keys
    assert_equal columns_before.sort, columns_after.sort
  ensure
    User.reset_column_information
  end

  def test_safe_change_table_custom_check
    assert_unsafe SafeChangeTableCustomCheck, "Cannot add forbidden column"
  end

  def test_safe_change_table_bulk
    skip unless mysql? || mariadb?

    statements = capture_statements do
      migrate SafeChangeTableBulk, direction: :up
    end
    alters = statements.select { |s| s.start_with?("ALTER TABLE") }
    assert_equal 1, alters.size
    migrate SafeChangeTableBulk, direction: :down
  end

  def test_safe_change_table_no_block
    assert_argument_error SafeChangeTableNoBlock
  end
end
