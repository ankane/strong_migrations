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

class RemoveIndexAlgorithmCopy < TestMigration
  def change
    remove_index :users, column: :name, algorithm: :copy
  end
end

class RemoveIndexAlgorithmInplace < TestMigration
  def change
    remove_index :users, column: :name, algorithm: :inplace
  end
end

class RemoveIndexLockShared < TestMigration
  def change
    remove_index :users, column: :name, lock: :shared
  end
end

class RemoveIndexLockNone < TestMigration
  def change
    remove_index :users, column: :name, lock: :none
  end
end

class RemoveIndexExtraArguments < TestMigration
  def change
    remove_index :users, :name, :extra
  end
end
