require_relative "test_helper"

class AddReferenceTest < Minitest::Test
  def test_add_reference_without_enabled_tables
    without_enabled_tables do
      assert_safe AddReference
    end
  end

  def test_add_reference
    skip unless postgresql?
    assert_unsafe AddReference
  end

  def test_add_reference_polymorphic
    skip unless postgresql?
    assert_unsafe AddReferencePolymorphic
  end

  def test_add_reference_no_index
    skip unless postgresql?
    assert_safe AddReferenceNoIndex
  end

  def test_add_reference_default
    skip unless postgresql?
    assert_unsafe AddReferenceDefault
  end

  def test_add_reference_concurrently
    skip unless postgresql?
    assert_safe AddReferenceConcurrently
  end

  def test_add_reference_foreign_key
    skip unless postgresql?
    assert_unsafe AddReferenceForeignKey, /Then add the foreign key/
  end

  def test_add_belongs_to
    skip unless postgresql?
    assert_unsafe AddBelongsTo
  end
end
