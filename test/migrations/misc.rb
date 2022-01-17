class AddColumnJson < TestMigration
  def change
    add_column :users, :properties, :json
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

class CreateTableForce < TestMigration
  def change
    create_table "users", force: :cascade do |t|
      t.string :name
    end
  end
end

class Custom < TestMigration
  def change
    add_column :users, :forbidden, :string
  end
end
