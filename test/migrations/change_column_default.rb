class ChangeColumnDefault < TestMigration
  def change
    change_column_default :users, :name, "Test"
  end
end

class ChangeColumnDefaultHash < TestMigration
  def change
    change_column_default :users, :name, from: nil, to: "Test"
  end
end

class ChangeColumnDefaultNewColumn < TestMigration
  def change
    add_column :users, :nice, :boolean
    change_column_default :users, :nice, from: nil, to: true
  end
end
