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
    if postgresql? || ActiveRecord::VERSION::STRING.to_f != 6.0
      assert_argument_error AddIndexExtraArguments
    else
      assert_type_error AddIndexExtraArguments
    end
  end

  def test_add_index_corruption
    # TODO fix
    skip # unless postgresql?
    outside_developer_env do
      with_target_version(14.3) do
        assert_unsafe AddIndex, "can cause silent data corruption in Postgres 14.0 to 14.3"
      end
    end
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

  def test_add_reference_foreign_key_on_delete
    assert_safe AddReferenceForeignKeyOnDelete
  end

  def test_add_reference_extra_arguments
    assert_argument_error AddReferenceExtraArguments
  end

  def test_add_foreign_key
    assert_safe AddForeignKey
  end

  def test_add_foreign_key_extra_arguments
    if postgresql? || ActiveRecord::VERSION::MAJOR >= 6
      assert_argument_error AddForeignKeyExtraArguments
    else
      assert_type_error AddForeignKeyExtraArguments
    end
  end

  def test_add_foreign_key_name
    skip if ActiveRecord::VERSION::MAJOR < 6

    migrate AddForeignKeyName
    foreign_keys = ActiveRecord::Schema.foreign_keys(:users)
    assert_equal 2, foreign_keys.size
    if postgresql?
      assert foreign_keys.all? { |fk| fk.options[:validate] }
    end

    migrate AddForeignKeyName, direction: :down
    assert_equal 0, ActiveRecord::Schema.foreign_keys(:users).size
  end

  def test_add_foreign_key_column
    skip if ActiveRecord::VERSION::MAJOR < 6

    migrate AddForeignKeyColumn
    foreign_keys = ActiveRecord::Schema.foreign_keys(:users)
    assert_equal 2, foreign_keys.size
    if postgresql?
      assert foreign_keys.all? { |fk| fk.options[:validate] }
    end

    migrate AddForeignKeyColumn, direction: :down
    assert_equal 0, ActiveRecord::Schema.foreign_keys(:users).size
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
