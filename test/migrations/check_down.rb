class CheckDown < TestMigration
  def up
    add_column :users, :age, :integer
  end

  def down
    remove_column :users, :age
  end
end

class CheckDownSafe < TestMigration
  def up
    add_column :users, :age, :integer
  end

  def down
    safety_assured do
      remove_column :users, :age
    end
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

class CheckDownSafetyAssured < TestMigration
  def change
    safety_assured do
      add_column :users, :age, :integer
    end
  end
end
