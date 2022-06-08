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

  def test_add_index_extra_arguments
    assert_argument_error AddIndexExtraArguments
  end

  def test_remove_index
    migrate AddIndex
    assert_safe RemoveIndex
    assert_safe RemoveIndexColumn
  ensure
    migrate AddIndex, direction: :down
  end

  def test_remove_index_name
    migrate AddIndexName
    migrate RemoveIndexName
  end

  def test_remove_index_options
    skip if ActiveRecord::VERSION::STRING.to_f < 6.1

    migrate RemoveIndexOptions
  end

  def test_remove_index_extra_arguments
    assert_argument_error RemoveIndexExtraArguments
  end

  def test_add_reference
    assert_safe AddReference
  end

  def test_add_reference_foreign_key
    assert_safe AddReferenceForeignKey
  end

  def test_add_reference_foreign_key_to_table
    assert_safe AddReferenceForeignKeyToTable
  end

  def test_add_reference_extra_arguments
    assert_argument_error AddReferenceExtraArguments
  end

  def test_add_foreign_key
    assert_safe AddForeignKey
  end

  def test_add_foreign_key_extra_arguments
    assert_argument_error AddForeignKeyExtraArguments
  end

  def test_add_check_constraint
    skip unless check_constraints? && postgresql?

    assert_safe AddCheckConstraint
  end

  def test_add_check_constraint_extra_arguments
    skip unless check_constraints? && postgresql?

    assert_argument_error AddCheckConstraintExtraArguments
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

  def test_change_column_null_default
    skip unless postgresql?

    # TODO add
    # User.create!
    error = assert_raises(StrongMigrations::Error) do
      with_target_version(12) do
        assert_safe ChangeColumnNullDefault
      end
    end
    assert_match "default value not supported yet with safe_by_default", error.message
  ensure
    User.delete_all
  end
end
