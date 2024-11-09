require_relative "test_helper"

class CheckDownTest < Minitest::Test
  def test_basic
    migrate CheckDown
    with_check_down do
      assert_unsafe CheckDown, direction: :down
    end
    assert_safe CheckDown, direction: :down
  end

  def test_safe
    migrate CheckDownSafe
    with_check_down do
      assert_safe CheckDownSafe, direction: :down
    end
  end

  def test_change
    skip unless postgresql?

    migrate CheckDownChange
    with_check_down do
      assert_unsafe CheckDownChange, direction: :down
    end
    assert_safe CheckDownChange, direction: :down
  end

  def test_change_safe
    skip unless postgresql?

    migrate CheckDownChangeSafe
    with_check_down do
      assert_safe CheckDownChangeSafe, direction: :down
    end
  end

  def test_safety_assured
    migrate CheckDownSafetyAssured
    with_check_down do
      assert_unsafe CheckDownSafetyAssured, direction: :down
    end
    assert_safe CheckDownSafetyAssured, direction: :down
  end

  def test_add_column
    migrate AddColumnDefault
    with_check_down do
      assert_unsafe AddColumnDefault, direction: :down
    end
    assert_safe AddColumnDefault, direction: :down
  end

  def test_add_index
    skip unless postgresql?

    migrate AddIndexConcurrently
    with_check_down do
      assert_safe AddIndexConcurrently, direction: :down
    end
  end

  def with_check_down
    StrongMigrations.check_down = true
    yield
  ensure
    StrongMigrations.check_down = false
  end
end
