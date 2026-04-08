require_relative "test_helper"

class RemoveIndexTest < Minitest::Test
  def test_concurrently
    skip unless postgresql?
    migrate AddIndexConcurrently

    begin
      StrongMigrations.enable_check(:remove_index)
      assert_unsafe RemoveIndex, "remove_index :users, :name, algorithm: :concurrently"
      assert_unsafe RemoveIndexExtraArguments, "remove_index :users, :name, algorithm: :concurrently"
      assert_unsafe RemoveIndexColumn
      assert_unsafe RemoveIndexName
      migrate RemoveIndexConcurrently
    ensure
      StrongMigrations.disable_check(:remove_index)
    end
  end

  def test_algorithm_copy
    skip unless mysql? || mariadb?

    migrate AddIndex
    if ar_version >= 8.2
      assert_unsafe RemoveIndexAlgorithmCopy
      migrate RemoveIndex
    else
      # algorithm option ignored for Active Record < 8.2
      migrate RemoveIndexAlgorithmCopy
    end
  end

  def test_algorithm_inplace
    skip unless mysql? || mariadb?

    migrate AddIndex
    # algorithm option ignored for Active Record < 8.2
    migrate RemoveIndexAlgorithmInplace
  end

  def test_lock_shared
    skip unless lock_option?

    migrate AddIndex
    assert_safe RemoveIndexLockShared
    migrate RemoveIndex
  end

  def test_lock_none
    skip unless lock_option?

    migrate AddIndex
    migrate RemoveIndexLockNone
  end

  def test_extra_arguments
    assert_argument_error RemoveIndexExtraArguments
  end
end
