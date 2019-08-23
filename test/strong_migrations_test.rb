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
    create_table "new_users" do |t|
      t.string :name
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

class ChangeColumnVarcharToText < TestMigration
  def change
    change_column :users, :name, :text
  end
end

class ChangeColumnNull < TestMigration
  def change
    change_column_null :users, :name, false, "Andy"
  end
end

class ChangeColumnNullNoDefault < TestMigration
  def change
    change_column_null :users, :name, false
  end
end

class ExecuteArbitrarySQL < TestMigration
  def change
    execute 'SELECT CURRENT_TIMESTAMP'
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
    remove_column :users, :name, :string
  end
end

class RemoveColumns < TestMigration
  def change
    remove_columns :users, :name, :other
  end
end

class RemoveTimestamps < TestMigration
  def change
    remove_timestamps :users
  end
end

class RemoveReference < TestMigration
  def change
    remove_reference :users, :device
  end
end

class RemoveReferencePolymorphic < TestMigration
  def change
    remove_reference :users, :device, polymorphic: true
  end
end

class RemoveBelongsTo < TestMigration
  def change
    remove_belongs_to :users, :device
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

class AddIndexColumnsUnique < TestMigration
  def change
    add_index :users, [:name, :name, :name, :name], unique: true, algorithm: :concurrently
  end
end

class AddReference < TestMigration
  def change
    add_reference :users, :device, index: true
  end
end

class AddReferencePolymorphic < TestMigration
  def change
    add_reference :users, :device, polymorphic: true, index: true
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

class AddReferenceConcurrently < TestMigration
  def change
    add_reference :users, :ip, index: {algorithm: :concurrently}
  end
end

class AddBelongsTo < TestMigration
  def change
    add_belongs_to :users, :device, index: true
  end
end

class CreateTableForce < TestMigration
  def change
    create_table "users", force: :cascade do |t|
      t.string :name
    end
  end
end

class VersionSafe < TestMigration
  def change
    change_column_null :users, :city, false, "San Francisco"
  end

  def version
    20170101000000
  end
end

class VersionUnsafe < TestMigration
  def change
    change_column_null :users, :city, false, "San Francisco"
  end

  def version
    20170101000001
  end
end

class AddForeignKey < TestMigration
  def change
    add_foreign_key :users, :orders
    remove_foreign_key :users, :orders
  end
end

class AddForeignKeySafe < TestMigration
  def change
    add_foreign_key :users, :orders, validate: false
    remove_foreign_key :users, :orders
  end
end

class Custom < TestMigration
  def change
    add_column :users, :forbidden, :string
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
    StrongMigrations.target_postgresql_version = 10
    assert_unsafe AddColumnDefault
  ensure
    StrongMigrations.target_postgresql_version = nil
  end

  def test_add_column_default_safe
    assert_safe AddColumnDefaultSafe
  end

  def test_add_column_json
    skip unless postgres?
    assert_unsafe AddColumnJson
  end

  def test_change_column
    assert_unsafe ChangeColumn
  end

  def test_change_column_varchar_to_text
    skip unless postgres?
    assert_safe ChangeColumnVarcharToText
  end

  def test_execute_arbitrary_sql
    assert_unsafe ExecuteArbitrarySQL
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

  def test_remove_columns
    assert_unsafe RemoveColumns
  end

  def test_remove_timestamps
    assert_unsafe RemoveTimestamps
  end

  def test_remove_reference
    assert_unsafe RemoveReference
  end

  def test_remove_reference_polymorphic
    assert_unsafe RemoveReferencePolymorphic
  end

  def test_remove_belongs_to
    assert_unsafe RemoveBelongsTo
  end

  def test_add_index_columns
    assert_unsafe AddIndexColumns, /more than three columns/
  end

  def test_add_index_columns_unique
    skip unless postgres?
    assert_safe AddIndexColumnsUnique
  end

  def test_add_reference
    skip unless postgres?
    assert_unsafe AddReference
  end

  def test_add_reference_polymorphic
    skip unless postgres?
    assert_unsafe AddReferencePolymorphic
  end

  def test_safe_add_reference
    skip unless postgres?
    assert_safe SafeAddReference
  end

  def test_add_reference_default
    skip unless postgres?
    assert_unsafe AddReferenceDefault
  end

  def test_add_reference_concurrently
    skip unless postgres?
    assert_safe AddReferenceConcurrently
  end

  def test_add_belongs_to
    skip unless postgres?
    assert_unsafe AddBelongsTo
  end

  def test_create_table_force
    assert_unsafe CreateTableForce
  end

  def test_version_safe
    assert_safe VersionSafe
  end

  def test_version_unsafe
    assert_unsafe VersionUnsafe
  end

  def test_change_column_null
    assert_unsafe ChangeColumnNull
  end

  def test_change_column_null_no_default
    assert_safe ChangeColumnNullNoDefault
  end

  def test_down
    assert_safe SafeUp
    assert_safe SafeUp, direction: :down
  end

  def test_add_foreign_key
    if postgres?
      assert_unsafe AddForeignKey
    else
      assert_safe AddForeignKey
    end
  end

  def test_add_foreign_key_safe
    if postgres? && ActiveRecord::VERSION::STRING <= "5.2"
      assert_unsafe AddForeignKeySafe
    else
      assert_safe AddForeignKeySafe
    end
  end

  def test_custom
    assert_unsafe Custom, "Cannot add forbidden column"
  end

  private

  def assert_unsafe(migration, message = nil)
    error = assert_raises(StrongMigrations::UnsafeMigration) { migrate(migration) }
    puts error.message if ENV["VERBOSE"]
    assert_match message, error.message if message
  end

  def assert_safe(migration, direction: :up)
    assert migrate(migration, direction: direction)
  end
end
