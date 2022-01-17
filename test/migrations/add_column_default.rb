class AddColumnDefault < TestMigration
  def change
    add_column :users, :nice, :boolean, default: true
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
