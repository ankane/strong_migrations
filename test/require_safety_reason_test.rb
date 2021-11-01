require_relative "test_helper"

class RequireSafetyReasonTest < Minitest::Test
  def setup
    StrongMigrations.require_safety_reason = true
  end

  def teardown
    StrongMigrations.require_safety_reason = false
  end

  def test_fail_without_reason
    assert_raises(StrongMigrations::Error) do
      migrate AddIndexSafetyAssured
    end
  end

  def test_passes_with_reason
    migrate AddIndexSafetyAssuredReason
  end
end
