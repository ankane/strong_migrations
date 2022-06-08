class RemoveIndex < TestMigration
  def change
    remove_index :users, :name
  end
end

class RemoveIndexColumn < TestMigration
  def change
    remove_index :users, column: :name
  end
end

class RemoveIndexName < TestMigration
  def change
    remove_index :users, name: "my_index"
  end
end

class RemoveIndexOptions < TestMigration
  def change
    remove_index :users, :name, name: "my_index", if_exists: true
  end
end

class RemoveIndexConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    remove_index :users, column: :name, algorithm: :concurrently
  end
end
