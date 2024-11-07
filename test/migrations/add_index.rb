class AddIndex < TestMigration
  def change
    add_index :users, :name
    add_index :users, :city
  end
end

class AddIndexUnique < TestMigration
  def change
    add_index :users, :name, unique: true
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
    create_table :new_users do |t|
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

class AddIndexColumns < TestMigration
  def change
    add_index :users, [:name, :city, :country, :deleted_at]
  end
end

class AddIndexColumnsUnique < TestMigration
  disable_ddl_transaction!

  def change
    add_index :users, [:name, :city, :country, :deleted_at], unique: true, algorithm: :concurrently
  end
end

class AddIndexName < TestMigration
  def change
    add_index :users, :name, name: "my_index"
  end
end

class AddIndexExtraArguments < TestMigration
  def change
    add_index :users, :name, :extra
  end
end

class AddIndexConcurrentlyExtraArguments < TestMigration
  def change
    add_index :users, :name, :extra, algorithm: :concurrently
  end
end
