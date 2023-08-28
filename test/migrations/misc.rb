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
    create_table :users, force: :cascade do |t|
      t.string :name
    end
  end
end

class CreateJoinTable < TestMigration
  def change
    create_join_table :users, :cities
  end
end

class CreateJoinTableForce < TestMigration
  def change
    create_join_table :users, :cities, force: :cascade
  end
end

class Custom < TestMigration
  def change
    add_column :users, :forbidden, :string
  end
end

class CustomAction < TestMigration
  disable_ddl_transaction!

  def change
    add_index :devices, :forbidden, algorithm: :concurrently
  end
end

class CustomVersion < TestMigration
  def change
    add_column :orders, :forbidden, :string
  end

  def version
    20170101000000
  end
end
