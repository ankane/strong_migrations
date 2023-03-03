class AddColumnDefault < TestMigration
  def change
    add_column :users, :nice, :boolean, default: true
  end
end

class AddColumnDefaultNull < TestMigration
  def change
    add_column :users, :nice, :boolean, default: nil
  end
end

class AddColumnDefaultNotNull < TestMigration
  def change
    add_column :users, :nice, :boolean, default: true, null: false
  end
end

class AddColumnDefaultSafe < TestMigration
  def change
    add_column :users, :nice, :boolean
    change_column_default :users, :nice, from: true, to: false
  end
end

class AddColumnDefaultCallable < TestMigration
  def change
    add_column :users, :nice, :datetime, default: -> { "clock_timestamp()" }
  end
end

class AddColumnDefaultUUID < TestMigration
  def change
    add_column :users, :nice, :uuid, default: "gen_random_uuid()"
  end
end

class AddColumnJson < TestMigration
  def change
    add_column :users, :properties, :json
  end
end

class AddColumnWithIndex < TestMigration
  def change
    add_column :users, :nice, :string, index: true
  end
end

class AddColumnWithUniqueIndex < TestMigration
  def change
    add_column :users, :nice, :string, index: :unique
  end
end
