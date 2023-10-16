class Version < TestMigration
  def change
    change_column_null :users, :city, false, "San Francisco"
  end

  def version
    20170101000001
  end
end

class AddTableDangerously < TestMigration
  def change
    create_table :dangerous_table, force: true do |t|
    end
  end
end

class AddTableDangerouslySafetyAssured < TestMigration
  def change
    safety_assured do
      create_table :dangerous_table, force: true do |t|
      end
    end
  end
end

class RevertAddTableDangerously < TestMigration
  def change
    revert AddTableDangerously
  end
end

class RevertAddTableDangerouslySafetyAssured < TestMigration
  def change
    safety_assured { revert AddTableDangerously }
  end
end
