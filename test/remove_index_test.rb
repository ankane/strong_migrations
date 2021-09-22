require_relative "test_helper"

class RemoveIndexTest < Minitest::Test
  def test_remove_index_concurrently_without_enabled_tables
    skip unless postgresql?
    migrate AddIndexConcurrently

    without_enabled_tables do
      StrongMigrations.enable_check(:remove_index)
      assert_safe RemoveIndex
      migrate RemoveIndexConcurrently
    ensure
      StrongMigrations.disable_check(:remove_index)
    end
  end

  def test_remove_index_concurrently
    skip unless postgresql?
    migrate AddIndexConcurrently

    begin
      StrongMigrations.enable_check(:remove_index)
      assert_unsafe RemoveIndex
      migrate RemoveIndexConcurrently
    ensure
      StrongMigrations.disable_check(:remove_index)
    end
  end
end
