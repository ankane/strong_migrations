require_relative "test_helper"

class AddIndex < TestMigration
  def change
    add_index :users, :name
  end
end

class AddIndexUp < TestMigration
  def self.up
    add_index :users, :name
  end
end

class AddIndexSafePostgres < TestMigration
  def change
    add_index :users, :name, algorithm: :concurrently
  end
end

class AddIndexSafetyAssured < TestMigration
  def change
    safety_assured { add_index :users, :name, name: "boom" }
  end
end

class AddIndexNewTable < TestMigration
  def change
    # needed for force: :cascade
    safety_assured do
      create_table "new_users", force: :cascade do |t|
        t.string :name
      end
    end

    add_index :new_users, :name
  end
end

class AddIndexSchema < TestSchema
  def change
    add_index :users, :name, name: "boom2"
  end
end

class AddColumnDefault < TestMigration
  def change
    add_column :users, :nice, :boolean, default: true
  end
end

class AddColumnDefaultSafe < TestMigration
  def change
    add_column :users, :nice, :boolean
    change_column_default :users, :nice, false
  end
end

class AddColumnJson < TestMigration
  def change
    add_column :users, :properties, :json
  end
end

class ChangeColumn < TestMigration
  def change
    change_column :users, :properties, :bad_name
  end
end

class RenameColumn < TestMigration
  def change
    rename_column :users, :properties, :bad_name
  end
end

class RenameTable < TestMigration
  def change
    rename_table :users, :bad_name
  end
end

class RemoveColumn < TestMigration
  def change
    remove_column :users, :name
  end
end

class SafeUp < TestMigration
  def change
    add_column :users, :email, :string
  end
end

class AddIndexColumns < TestMigration
  def change
    add_index :users, [:name, :city, :state, :zip_code]
  end
end

class AddReference < TestMigration
  def change
    add_reference :users, :device, index: true
  end
end

class SafeAddReference < TestMigration
  def change
    add_reference :users, :country, index: false
  end
end

class AddReferenceDefault < TestMigration
  def change
    add_reference :users, :ip
  end
end

class CreateTableForce < TestMigration
  def change
    create_table "users", force: :cascade do |t|
      t.string :name
    end
  end
end

class StrongMigrationsTest < StrongMigrationsTestBase
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

  def test_add_index_new_table
    assert_safe AddIndexNewTable
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

  def test_add_reference
    skip unless postgres?
    assert_unsafe AddReference
  end

  def test_safe_add_reference
    skip unless postgres?
    assert_safe SafeAddReference
  end

  def test_add_reference_default
    skip unless postgres?
    if ActiveRecord::VERSION::MAJOR >= 5
      assert_unsafe AddReferenceDefault
    else
      assert_safe AddReferenceDefault
    end
  end

  def test_create_table_force
    assert_unsafe CreateTableForce
  end

  def test_down
    assert_safe SafeUp
    assert_safe SafeUp, direction: :down
  end

  def test_old_remove_column_assumed_safe
    with_safety_assumed_prior_to(RemoveColumn.new.version + 1) do
      assert_safe RemoveColumn
    end
  end

  def test_remove_column_at_cutoff_version_assumed_safe
    with_safety_assumed_prior_to(RemoveColumn.new.version) do
      assert_safe RemoveColumn
    end
  end

  def test_new_remove_column_not_assumed_safe
    with_safety_assumed_prior_to(RemoveColumn.new.version - 1) do
      assert_unsafe RemoveColumn
    end
  end

  def assert_unsafe(migration, message = nil)
    error = assert_raises(StrongMigrations::UnsafeMigration) { migrate(migration) }
    assert_match message, error.message if message
  end

  def assert_safe(migration, direction: :up)
    assert migrate(migration, direction: direction)
  end
end
