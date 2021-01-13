require_relative "test_helper"

class SafeByDefaultTest < Minitest::Test
  def setup
    StrongMigrations.safe_by_default = true
  end

  def teardown
    StrongMigrations.safe_by_default = false
  end

  def test_add_index
    assert_safe AddIndex
  end

  def test_remove_index
    migrate AddIndex
    assert_safe RemoveIndex
  ensure
    migrate AddIndex, direction: :down
  end

  def test_add_reference
    assert_safe AddReference
  end

  def test_add_reference_foreign_key
    assert_safe AddReferenceForeignKey
  end

  def test_add_foreign_key
    assert_safe AddForeignKey
  end

  def test_add_check_constraint
    skip unless check_constraints? && postgresql?

    assert_safe AddCheckConstraint
  end

  def test_change_column_null
    skip unless postgresql?

    with_target_version(12) do
      assert_safe ChangeColumnNull
    end
  end

  def test_change_column_null_constraint
    skip unless postgresql?

    with_target_version(11) do
      assert_safe ChangeColumnNull
    end
  end
end
