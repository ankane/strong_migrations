require_relative "test_helper"

class AddReferenceTest < Minitest::Test
  def test_basic
    skip unless postgresql?
    assert_unsafe AddReference
  end

  def test_polymorphic
    skip unless postgresql?
    assert_unsafe AddReferencePolymorphic
  end

  def test_no_index
    skip unless postgresql?
    assert_safe AddReferenceNoIndex
  end

  def test_default
    skip unless postgresql?
    assert_unsafe AddReferenceDefault
  end

  def test_concurrently
    skip unless postgresql?
    assert_safe AddReferenceConcurrently
  end

  def test_foreign_key
    skip unless postgresql?
    assert_unsafe AddReferenceForeignKey, /Then add the foreign key/
  end

  def test_add_belongs_to
    skip unless postgresql?
    assert_unsafe AddBelongsTo
  end
end
