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

  def test_extra_arguments
    assert_argument_error RemoveIndexExtraArguments
  end
end
