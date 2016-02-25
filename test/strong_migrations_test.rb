require_relative "test_helper"

class AddIndex < ActiveRecord::Migration
  def change
    add_index :users, :name
  end
end

class AddIndexUp < ActiveRecord::Migration
  def self.up
    add_index :users, :name
  end
end

class AddIndexSafePostgres < ActiveRecord::Migration
  def change
    add_index :users, :name, algorithm: :concurrently
  end
end

class AddIndexSafetyAssured < ActiveRecord::Migration
  def change
    safety_assured { add_index :users, :name, name: "boom" }
  end
end

class AddIndexSchema < ActiveRecord::Schema
  def change
    add_index :users, :name, name: "boom2"
  end
end

class AddColumnDefault < ActiveRecord::Migration
  def change
    add_column :users, :nice, :boolean, default: true
  end
end

class AddColumnDefaultSafe < ActiveRecord::Migration
  def change
    add_column :users, :nice, :boolean
    change_column_default :users, :nice, false
  end
end

class AddColumnJson < ActiveRecord::Migration
  def change
    add_column :users, :properties, :json
  end
end

class ChangeColumn < ActiveRecord::Migration
  def change
    change_column :users, :properties, :bad_name
  end
end

class RenameColumn < ActiveRecord::Migration
  def change
    rename_column :users, :properties, :bad_name
  end
end

class RenameTable < ActiveRecord::Migration
  def change
    rename_table :users, :bad_name
  end
end

class RemoveColumn < ActiveRecord::Migration
  def change
    remove_column :users, :name
  end
end

class SafeUp < ActiveRecord::Migration
  def change
    add_column :users, :email, :string
  end
end

class AddIndexColumns < ActiveRecord::Migration
  def change
    add_index :users, [:name, :city, :state, :zip_code]
  end
end

class StrongMigrationsTest < Minitest::Test
  def test_add_index
    skip unless postgres?
    assert_unsafe AddIndex
  end

  def test_add_index_up
    skip unless postgres?
    assert_unsafe AddIndexUp
  end

  def test_add_index_safety_assured
    assert_safe AddIndexSafetyAssured
  end

  def test_schema
    assert_safe AddIndexSchema
  end

  def test_add_index_safe_postgres
    skip unless postgres?
    assert_safe AddIndexSafePostgres
  end

  def test_add_column_default
    assert_unsafe AddColumnDefault
  end

  def test_add_column_default_safe
    assert_safe AddColumnDefaultSafe
  end

  def test_add_column_json
    assert_unsafe AddColumnJson
  end

  def test_change_column
    assert_unsafe ChangeColumn
  end

  def test_rename_column
    assert_unsafe RenameColumn
  end

  def test_rename_table
    assert_unsafe RenameTable
  end

  def test_remove_column
    assert_unsafe RemoveColumn
  end

  def test_add_index_columns
    assert_unsafe AddIndexColumns, /more than three columns/
  end

  def test_down
    assert_safe SafeUp
    assert_safe SafeUp, direction: :down
  end

  def assert_unsafe(migration, message = nil)
    error = assert_raises(StrongMigrations::UnsafeMigration) { migrate(migration) }
    if message
      assert_match message, error.message
    end
  end

  def assert_safe(migration, direction: :up)
    assert migrate(migration, direction: direction)
  end
end
