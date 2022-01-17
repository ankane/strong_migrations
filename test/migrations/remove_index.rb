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
