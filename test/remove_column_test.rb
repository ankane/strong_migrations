require_relative "test_helper"

class RemoveColumnTest < Minitest::Test
  def test_remove_column_without_enabled_tables
    without_enabled_tables do
      assert_safe RemoveColumn
    end
  end

  def test_remove_column
    assert_unsafe RemoveColumn
  end

  def test_remove_columns
    assert_unsafe RemoveColumns
  end

  def test_remove_timestamps
    assert_unsafe RemoveTimestamps
  end

  def test_remove_reference
    assert_unsafe RemoveReference
  end

  def test_remove_reference_polymorphic
    assert_unsafe RemoveReferencePolymorphic
  end

  def test_remove_belongs_to
    assert_unsafe RemoveBelongsTo
  end
end
