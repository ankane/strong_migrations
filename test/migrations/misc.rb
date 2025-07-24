class ExecuteArbitrarySQL < TestMigration
  def change
    execute "SELECT 1"
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

class RenameSchema < TestMigration
  def change
    rename_schema :public, :bad_name
  end
end

class CreateTableForce < TestMigration
  def change
    create_table :admins, force: :cascade do |t|
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

class RevertAddReference < TestMigration
  def change
    revert AddReferenceNoIndex
  end
end

class RevertAddReferenceSafetyAssured < TestMigration
  def change
    safety_assured { revert AddReferenceNoIndex }
  end
end

class RevertAddReferenceInline < TestMigration
  def change
    revert { add_reference :users, :country, index: false }
  end
end

class RevertCreateTableForce < TestMigration
  def change
    revert CreateTableForce
  end
end

class RevertCreateTableForceInline < TestMigration
  def change
    revert do
      create_table :admins, force: :cascade do |t|
        t.string :name
      end
    end
  end
end

class Custom < TestMigration
  def change
    add_column :users, :forbidden, :string
  end
end
