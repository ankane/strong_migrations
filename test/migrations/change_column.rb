class ChangeColumn < TestMigration
  def change
    change_column :users, :properties, :bad_name
  end
end

class ChangeColumnVarcharToText < TestMigration
  def up
    change_column :users, :name, :text
  end

  def down
    change_column :users, :name, :string
  end
end

class ChangeColumnVarcharIncreaseLimit < TestMigration
  def up
    change_column :users, :country, :string, limit: 21
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharIncreaseLimit256 < TestMigration
  def up
    change_column :users, :country, :string, limit: 256
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharDecreaseLimit < TestMigration
  def up
    change_column :users, :country, :string, limit: 19
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharRemoveLimit < TestMigration
  def up
    change_column :users, :country, :string
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnVarcharAddLimit < TestMigration
  def up
    change_column :users, :country, :string
    change_column :users, :country, :string, limit: 20
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnTextToVarcharLimit < TestMigration
  def up
    change_column :users, :country, :text
    change_column :users, :country, :string, limit: 20
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnTextToVarcharNoLimit < TestMigration
  def up
    change_column :users, :country, :text
    change_column :users, :country, :string
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end

class ChangeColumnDecimalDecreasePrecision < TestMigration
  def up
    change_column :users, :credit_score, :decimal, precision: 9, scale: 5
  end
end

class ChangeColumnDecimalChangeScale < TestMigration
  def up
    change_column :users, :credit_score, :decimal, precision: 10, scale: 6
  end
end

class ChangeColumnDecimalIncreasePrecision < TestMigration
  def up
    change_column :users, :credit_score, :decimal, precision: 11, scale: 5
  end

  def down
    change_column :users, :credit_score, :decimal, precision: 10, scale: 5
  end
end

class ChangeColumnDecimalUnconstrained < TestMigration
  def up
    change_column :users, :credit_score, :decimal
  end

  def down
    change_column :users, :credit_score, :decimal, precision: 10, scale: 5
  end
end

class ChangeColumnTimestamps < TestMigration
  def up
    change_column :users, :deleted_at, :timestamptz
    change_column :users, :deleted_at, :timestamp
  end
end

class ChangeColumnWithNotNull < TestMigration
  def up
    change_column :users, :country, :string, limit: 20, null: false
  end

  def down
    change_column :users, :country, :string, limit: 20
  end
end
