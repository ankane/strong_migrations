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

  def test_revert_before_start_after_safe
    with_start_after(20170101000000) do
      migrate AddTableDangerously
      assert_safe RevertAddTableDangerously
      migrate RevertAddTableDangerouslySafetyAssured
    end
  end

  def test_revert_before_start_after_unsafe
    with_start_after(1) do
      migrate AddTableDangerouslySafetyAssured
      assert_unsafe RevertAddTableDangerously
      migrate RevertAddTableDangerouslySafetyAssured
    end
  end

  def with_start_after(start_after)
    StrongMigrations.stub(:start_after, start_after) do
      yield
    end
  end
end
