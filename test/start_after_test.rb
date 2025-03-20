require_relative "test_helper"

class StartAfterTest < Minitest::Test
  def test_version_safe
    with_start_after(20170101000001) do
      assert_safe Version
    end
  end

  def test_version_unsafe
    with_start_after(20170101000000) do
      assert_unsafe Version
    end
  end

  def test_revert_version_safe
    migrate AddReferenceNoIndex
    with_start_after(20170101000001) do
      assert_safe RevertAddReference, version: 20170101000001
    end
  ensure
    migrate AddReferenceNoIndex, direction: :down
  end

  def test_revert_version_unsafe
    with_start_after(20170101000000) do
      assert_unsafe RevertAddReference, version: 20170101000001
    end
  end
end
