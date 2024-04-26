class CreateTableWithInteger < TestMigration
  def up
    create_table :test_table do |t|
      t.integer :test_column
    end
  end

  def down
    drop_table :test_table
  end
end

class CreateTableWithIntegerColumnCall < TestMigration
  def up
    create_table :test_table do |t|
      t.column :test_column, :integer
    end
  end

  def down
    drop_table :test_table
  end
end

class CreateTableWithSafetyAssured < TestMigration
  def up
    create_table :test_table do |t|
      safety_assured { t.integer :test_column }
    end
  end

  def down
    drop_table :test_table
  end
end
