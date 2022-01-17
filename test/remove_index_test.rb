require_relative "test_helper"

class RemoveIndexTest < Minitest::Test
  def test_concurrently
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
