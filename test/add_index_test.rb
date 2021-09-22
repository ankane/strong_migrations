require_relative "test_helper"

class AddIndexTest < Minitest::Test
  def test_add_index_without_enabled_tables
    without_enabled_tables do
      assert_safe AddIndex
    end
  end

  def test_add_index
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

  def test_add_index_up
    if postgresql?
      assert_unsafe AddIndexUp
    else
      assert_safe AddIndexUp
    end
  end

  def test_add_index_safety_assured
    assert_safe AddIndexSafetyAssured
  end

  def test_add_index_new_table
    assert_safe AddIndexNewTable
  end

  def test_schema
    assert_safe AddIndexSchema
  end

  def test_add_index_concurrently
    skip unless postgresql?
    assert_safe AddIndexConcurrently
  end

  def test_add_index_columns
    assert_unsafe AddIndexColumns, /more than three columns/
  end

  def test_add_index_columns_unique
    skip unless postgresql?
    assert_safe AddIndexColumnsUnique
  end

  def test_auto_analyze
    StrongMigrations.auto_analyze = true
    assert_safe AddIndexSafetyAssured
  ensure
    StrongMigrations.auto_analyze = false
  end
end
