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
