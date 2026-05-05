class ChangeTable < TestMigration
  def change
    change_table :users do |t|
      t.string :nice
    end
  end
end

class SafeChangeTable < TestMigration
  def up
    safe_change_table :users do |t|
      t.string :first_name
      t.string :last_name
    end
  end

  def down
    remove_column :users, :first_name
    remove_column :users, :last_name
  end
end

class SafeChangeTableUnsafe < TestMigration
  def change
    safe_change_table :users do |t|
      t.remove :name
    end
  end
end

class SafeChangeTableCustomCheck < TestMigration
  def change
    safe_change_table :users do |t|
      t.string :forbidden
    end
  end
end

class SafeChangeTableBulk < TestMigration
  def up
    safe_change_table :users, bulk: true do |t|
      t.string :first_name
      t.string :last_name
    end
  end

  def down
    remove_column :users, :first_name
    remove_column :users, :last_name
  end
end

class SafeChangeTableNoBlock < TestMigration
  def change
    safe_change_table :users
  end
end

class ChangeTableSafeOps < TestMigration
  def up
    change_table :users do |t|
      t.string :first_name
      t.string :last_name
    end
  end

  def down
    remove_column :users, :first_name
    remove_column :users, :last_name
  end
end

class ChangeTableUnsafeOp < TestMigration
  def change
    change_table :users do |t|
      t.remove :name
    end
  end
end
