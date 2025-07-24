require_relative "test_helper"

class AddReferenceTest < Minitest::Test
  def test_basic
    if postgresql?
      assert_unsafe AddReference
    else
      assert_safe AddReference
    end
  end

  def test_polymorphic
    if postgresql?
      assert_unsafe AddReferencePolymorphic
    else
      assert_safe AddReferencePolymorphic
    end
  end

  def test_no_index
    assert_safe AddReferenceNoIndex
  end

  def test_default
    if postgresql?
      assert_unsafe AddReferenceDefault
    else
      assert_safe AddReferenceDefault
    end
  end

  def test_concurrently
    skip unless postgresql?
    assert_safe AddReferenceConcurrently
  end

  def test_foreign_key
    if postgresql?
      assert_unsafe AddReferenceForeignKey, "Then add the foreign key"
    else
      assert_safe AddReferenceForeignKey
    end
  end

  def test_add_belongs_to
    if postgresql?
      assert_unsafe AddBelongsTo
    else
      assert_safe AddBelongsTo
    end
  end

  def test_auto_analyze
    with_auto_analyze do
      assert_analyzed postgresql? ? AddReferenceConcurrently : AddReference
    end
  end

  def test_auto_analyze_false
    refute_analyzed postgresql? ? AddReferenceConcurrently : AddReference
  end

  def test_auto_analyze_no_index
    with_auto_analyze do
      refute_analyzed AddReferenceNoIndex
    end
  end

  def test_auto_analyze_default
    with_auto_analyze do
      with_safety_assured do
        assert_analyzed AddReferenceDefault
      end
    end
  end

  def test_auto_analyze_add_belongs_to
    with_auto_analyze do
      with_safety_assured do
        assert_analyzed AddBelongsTo
      end
    end
  end

  def test_extra_arguments
    if postgresql?
      assert_unsafe AddReferenceExtraArguments
    else
      assert_argument_error AddReferenceExtraArguments
    end
  end
end
