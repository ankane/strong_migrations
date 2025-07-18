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

  def test_extra_arguments
    if postgresql?
      assert_unsafe AddReferenceExtraArguments
    else
      assert_argument_error AddReferenceExtraArguments
    end
  end

  def test_auto_analyze_with_index
    StrongMigrations.auto_analyze = true
    logs = capture_logs { assert_safe AddReferenceConcurrently }
    assert_includes logs, "ANALYZE"
  ensure
    StrongMigrations.auto_analyze = false
  end

  def test_auto_analyze_skips_analyze_without_index
    StrongMigrations.auto_analyze = true
    logs = capture_logs { assert_safe AddReferenceNoIndex }
    refute logs.include?("ANALYZE")
  ensure
    StrongMigrations.auto_analyze = false
  end
end
