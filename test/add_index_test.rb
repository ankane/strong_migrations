require_relative "test_helper"

class AddIndexTest < Minitest::Test
  def test_non_concurrently
    if postgresql?
      assert_unsafe AddIndex, <<~EOF
        Adding an index non-concurrently blocks writes. Instead, use:

        class AddIndex < ActiveRecord::Migration[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]
          disable_ddl_transaction!

          def change
            add_index :users, :name, algorithm: :concurrently
          end
        end
      EOF
    else
      assert_safe AddIndex
    end
  end

  def test_up
    if postgresql?
      assert_unsafe AddIndexUp
    else
      assert_safe AddIndexUp
    end
  end

  def test_safety_assured
    assert_safe AddIndexSafetyAssured
  end

  def test_new_table
    assert_safe AddIndexNewTable
  end

  def test_schema
    assert_safe AddIndexSchema
  end

  def test_versioned_schema
    skip if ActiveRecord.version < Gem::Version.new("7.0.2")

    # use define like db/schema.rb
    ActiveRecord::Schema[migration_version].define do
      add_index :users, :name, name: "boom2"
      remove_index :users, name: "boom2"
    end
  end

  def test_concurrently
    skip unless postgresql?
    assert_safe AddIndexConcurrently
  end

  def test_columns
    assert_unsafe AddIndexColumns, "more than three columns"
  end

  def test_columns_unique
    skip unless postgresql?
    assert_safe AddIndexColumnsUnique
  end

  def test_auto_analyze
    StrongMigrations.auto_analyze = true
    assert_safe AddIndexSafetyAssured
  ensure
    StrongMigrations.auto_analyze = false
  end

  def test_extra_arguments
    if postgresql?
      assert_unsafe AddIndexExtraArguments
    else
      assert_argument_error AddIndexExtraArguments
    end
  end

  def test_concurrently_extra_arguments
    assert_argument_error AddIndexConcurrentlyExtraArguments
  end

  def test_corruption
    # TODO fix
    skip # unless postgresql?
    outside_developer_env do
      with_target_version(14.3) do
        assert_unsafe AddIndexConcurrently, "can cause silent data corruption in Postgres 14.0 to 14.3"
      end
    end
  end

  def test_lock_timeout
    skip unless postgresql?

    with_locked_table("users") do
      with_lock_timeout(0.1) do
        assert_raises(ActiveRecord::LockWaitTimeout) do
          migrate AddIndexConcurrently
        end
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      migrate AddIndexConcurrently
    end

    migrate AddIndexConcurrently, direction: :down
  end
end
