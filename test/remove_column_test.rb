require_relative "test_helper"

class RemoveColumnTest < Minitest::Test
  def test_remove_column
    assert_unsafe RemoveColumn
  end

  def test_remove_columns
    assert_unsafe RemoveColumns
  end

  def test_remove_columns_type
    assert_unsafe RemoveColumnsType, 'self.ignored_columns = ["name", "other"]'
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
