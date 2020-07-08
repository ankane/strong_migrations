class AddIndex < TestMigration
  def change
    add_index :users, :name
  end
end

class RemoveIndex < TestMigration
  def change
    remove_index :users, column: :name, name: "index_users_on_name"
  end
end

class RemoveIndexConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    remove_index :users, column: :name, name: "index_users_on_name", algorithm: :concurrently
  end
end

class AddIndexUp < TestMigration
  def self.up
    add_index :users, :name
  end

  def self.down
    remove_index :users, :name
  end
end

class AddIndexConcurrently < TestMigration
  disable_ddl_transaction!

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

class AddColumnDefaultNotNull < TestMigration
  def change
    add_column :users, :nice, :boolean, default: true, null: false
  end
end

class AddColumnDefaultSafe < TestMigration
  def change
    add_column :users, :nice, :boolean
    change_column_default :users, :nice, from: true, to: false
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
  def up
    change_column :users, :name, :text
  end

  def down
    change_column :users, :name, :string
  end
end

class ChangeColumnVarcharIncreaseLimit < TestMigration
  def up
    change_column :users, :country, :string, limit: 21
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharIncreaseLimit256 < TestMigration
  def up
    change_column :users, :country, :string, limit: 256
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharDecreaseLimit < TestMigration
  def up
    change_column :users, :country, :string, limit: 19
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharRemoveLimit < TestMigration
  def up
    change_column :users, :country, :string
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnDecimalDecreasePrecision < TestMigration
  def up
    change_column :users, :credit_score, :decimal, precision: 9, scale: 5
  end
end

class ChangeColumnDecimalChangeScale < TestMigration
  def up
    change_column :users, :credit_score, :decimal, precision: 10, scale: 6
  end
end

class ChangeColumnDecimalIncreasePrecision < TestMigration
  def up
    change_column :users, :credit_score, :decimal, precision: 11, scale: 5
  end

  def down
    change_column :users, :credit_score, :decimal, precision: 10, scale: 5
  end
end

class ChangeColumnDecimalUnconstrained < TestMigration
  def up
    change_column :users, :credit_score, :decimal
  end

  def down
    change_column :users, :credit_score, :decimal, precision: 10, scale: 5
  end
end

class ChangeColumnTimestamps < TestMigration
  def up
    change_column :users, :deleted_at, :timestamptz
    change_column :users, :deleted_at, :timestamp
  end
end

class ChangeColumnNull < TestMigration
  def change
    change_column_null :users, :name, false
  end
end

class ChangeColumnNullConstraint < TestMigration
  def up
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "test" CHECK ("name" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "test"'
    end
    change_column_null :users, :name, false
  end

  def down
    execute 'ALTER TABLE "users" DROP CONSTRAINT "test"'
    change_column_null :users, :name, true
  end
end

class ChangeColumnNullConstraintUnvalidated < TestMigration
  def up
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "test" CHECK ("name" IS NOT NULL) NOT VALID'
    end
    change_column_null :users, :name, false
  end

  def down
    execute 'ALTER TABLE "users" DROP CONSTRAINT "test"'
    change_column_null :users, :name, true
  end
end

class ChangeColumnNullDefault < TestMigration
  def change
    change_column_null :users, :name, false, "Andy"
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
  disable_ddl_transaction!

  def change
    add_index :users, :name, unique: true, algorithm: :concurrently
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

class AddReferenceNoIndex < TestMigration
  def change
    add_reference :users, :country, index: false
  end
end

class AddReferenceDefault < TestMigration
  def change
    add_reference :users, :ip
  end
end

class AddReferenceForeignKey < TestMigration
  def change
    add_reference :users, :device, foreign_key: true, index: false
  end
end

class AddReferenceConcurrently < TestMigration
  disable_ddl_transaction!

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

class Version < TestMigration
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
  end
end

class AddForeignKeySafe < TestMigration
  def change
    add_foreign_key :users, :orders, validate: false
  end
end

class AddForeignKeyValidateSameTransaction < TestMigration
  def change
    add_foreign_key :users, :orders, validate: false
    validate_foreign_key :users, :orders
  end
end

class AddForeignKeyValidateNoTransaction < TestMigration
  disable_ddl_transaction!

  def change
    add_foreign_key :users, :orders, validate: false
    validate_foreign_key :users, :orders
  end
end

class Custom < TestMigration
  def change
    add_column :users, :forbidden, :string
  end
end

class CheckTimeouts < TestMigration
  include Helpers

  def change
    safety_assured { execute "SELECT 1" }

    $statement_timeout =
      if postgresql?
        connection.select_all("SHOW statement_timeout").first["statement_timeout"]
      elsif mysql?
        connection.select_all("SHOW VARIABLES LIKE 'max_execution_time'").first["Value"].to_i / 1000
      else
        connection.select_all("SHOW VARIABLES LIKE 'max_statement_time'").first["Value"].to_i
      end

    $lock_timeout =
      if postgresql?
        connection.select_all("SHOW lock_timeout").first["lock_timeout"]
      else
        connection.select_all("SHOW VARIABLES LIKE 'lock_wait_timeout'").first["Value"].to_i
      end
  end
end

class CheckLockTimeout < TestMigration
  def change
    safety_assured { execute "SELECT 1" }
  end
end

class AddForeignKeySafely < TestMigration
  disable_ddl_transaction!

  def change
    add_foreign_key_safely :users, :orders
  end
end

class AddNullConstraintSafely < TestMigration
  disable_ddl_transaction!

  def change
    add_null_constraint_safely :users, :name
  end
end

class CheckDown < TestMigration
  def up
    add_column :users, :age, :integer
  end

  def down
    remove_column :users, :age
  end
end

class CheckDownChange < TestMigration
  disable_ddl_transaction!

  def change
    add_index :users, :name, algorithm: :concurrently
    remove_index :users, :name
  end
end

class CheckDownChangeSafe < TestMigration
  disable_ddl_transaction!

  def change
    add_index :users, :name, algorithm: :concurrently
    remove_index :users, column: :name, algorithm: :concurrently
  end
end
