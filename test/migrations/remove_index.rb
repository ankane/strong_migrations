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
    remove_index :users, name: "index_users_on_name"
  end
end

class RemoveIndexConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    remove_index :users, column: :name, algorithm: :concurrently
  end
end
