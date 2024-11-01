require_relative "test_helper"

class CheckDownTest < Minitest::Test
  def test_check_down
    migrate CheckDown
    assert_safe CheckDown, direction: :down

    migrate CheckDown
    with_check_down do
      assert_unsafe CheckDown, direction: :down
    end
    migrate CheckDown, direction: :down
  end

  def test_check_down_safe
    migrate CheckDownSafe
    with_check_down do
      assert_safe CheckDownSafe, direction: :down
    end
  end

  def test_check_down_change
    skip unless postgresql?

    migrate CheckDownChange
    assert_safe CheckDownChange, direction: :down

    migrate CheckDownChange
    with_check_down do
      assert_unsafe CheckDownChange, direction: :down
    end
    migrate CheckDownChange, direction: :down
  end

  def test_check_down_change_safe
    skip unless postgresql?

    migrate CheckDownChangeSafe
    with_check_down do
      assert_safe CheckDownChangeSafe, direction: :down
    end
  end

  def with_check_down
    StrongMigrations.check_down = true
    yield
  ensure
    StrongMigrations.check_down = false
  end
end
