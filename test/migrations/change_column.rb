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

class ChangeColumnVarcharToCitext < TestMigration
  def up
    change_column :users, :name, :citext
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

class ChangeColumnVarcharIncreaseLimit64 < TestMigration
  def up
    change_column :users, :country, :string, limit: 64
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
    change_column :users, :description, :string, limit: 20
  end

  def down
    change_column :users, :description, :text
  end
end

class ChangeColumnTextToVarcharNoLimit < TestMigration
  def up
    change_column :users, :description, :string
  end

  def down
    change_column :users, :description, :text
  end
end

class ChangeColumnTextToCitext < TestMigration
  def up
    change_column :users, :description, :citext
  end

  def down
    change_column :users, :description, :text
  end
end

class ChangeColumnTextToCitextIndexed < TestMigration
  def up
    safety_assured { add_index :users, :description }
    change_column :users, :description, :citext
  end

  def down
    change_column :users, :description, :text
    remove_index :users, :description
  end
end

class ChangeColumnTextToCitextIndexedExpression < TestMigration
  def up
    safety_assured { add_index :users, "lower(description)" }
    change_column :users, :description, :citext
  end

  def down
    change_column :users, :description, :text
    remove_index :users, :description
  end
end

class ChangeColumnCitextToText < TestMigration
  def up
    change_column :users, :code, :text
  end

  def down
    change_column :users, :code, :citext
  end
end

class ChangeColumnCitextToTextIndexed < TestMigration
  def up
    safety_assured { add_index :users, :code }
    change_column :users, :code, :text
  end

  def down
    change_column :users, :code, :citext
    remove_index :users, :code
  end
end

class ChangeColumnCitextToVarcharLimit < TestMigration
  def up
    change_column :users, :code, :string, limit: 20
  end

  def down
    change_column :users, :code, :citext
  end
end

class ChangeColumnCitextToVarcharNoLimit < TestMigration
  def up
    change_column :users, :code, :string
  end

  def down
    change_column :users, :code, :citext
  end
end

class ChangeColumnCitextToVarcharNoLimitIndexed < TestMigration
  def up
    safety_assured { add_index :users, :code }
    change_column :users, :code, :string
  end

  def down
    change_column :users, :code, :citext
    remove_index :users, :code
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

class ChangeColumnDatetimeIncreasePrecision < TestMigration
  def up
    add_column :users, :joined_at, :datetime, precision: 0
    change_column :users, :joined_at, :datetime, precision: 3
    change_column :users, :joined_at, :datetime, precision: 6
    change_column :users, :joined_at, :datetime
    change_column :users, :joined_at, :datetime, precision: 6
  end

  def down
    remove_column :users, :joined_at
  end
end

class ChangeColumnDatetimeDecreasePrecision < TestMigration
  def up
    add_column :users, :joined_at, :datetime
    change_column :users, :joined_at, :datetime, precision: 3
  end

  def down
    remove_column :users, :joined_at
  end
end

class ChangeColumnTimestampIncreaseLimit < TestMigration
  def up
    add_column :users, :joined_at, :timestamp, limit: 0
    change_column :users, :joined_at, :timestamp, limit: 3
    change_column :users, :joined_at, :timestamp, limit: 6
    change_column :users, :joined_at, :timestamp
    change_column :users, :joined_at, :timestamp, limit: 6
  end

  def down
    remove_column :users, :joined_at
  end
end

class ChangeColumnTimestampDecreaseLimit < TestMigration
  def up
    add_column :users, :joined_at, :timestamp
    change_column :users, :joined_at, :timestamp, limit: 3
  end

  def down
    remove_column :users, :joined_at
  end
end

class ChangeColumnTimestamptzIncreaseLimit < TestMigration
  def up
    add_column :users, :joined_at, :timestamptz, limit: 0
    change_column :users, :joined_at, :timestamptz, limit: 3
    change_column :users, :joined_at, :timestamptz, limit: 6
    change_column :users, :joined_at, :timestamptz
    change_column :users, :joined_at, :timestamptz, limit: 6
  end

  def down
    remove_column :users, :joined_at
  end
end

class ChangeColumnTimestamptzDecreaseLimit < TestMigration
  def up
    add_column :users, :joined_at, :timestamptz
    change_column :users, :joined_at, :timestamptz, limit: 3
  end

  def down
    remove_column :users, :joined_at
  end
end

class ChangeColumnTimeIncreasePrecision < TestMigration
  def up
    add_column :users, :opens_at, :time, precision: 0
    change_column :users, :opens_at, :time, precision: 3
    change_column :users, :opens_at, :time, precision: 6
    change_column :users, :opens_at, :time
    change_column :users, :opens_at, :time, precision: 6
  end

  def down
    remove_column :users, :opens_at
  end
end

class ChangeColumnTimeDecreasePrecision < TestMigration
  def up
    add_column :users, :opens_at, :time
    change_column :users, :opens_at, :time, precision: 3
  end

  def down
    remove_column :users, :opens_at
  end
end

class ChangeColumnIntervalIncreasePrecision < TestMigration
  def up
    add_column :users, :duration, :interval, precision: 0
    change_column :users, :duration, :interval, precision: 3
    change_column :users, :duration, :interval, precision: 6
    change_column :users, :duration, :interval
    change_column :users, :duration, :interval, precision: 6
  end

  def down
    remove_column :users, :duration
  end
end

class ChangeColumnIntervalDecreasePrecision < TestMigration
  def up
    add_column :users, :duration, :interval
    change_column :users, :duration, :interval, precision: 3
  end

  def down
    remove_column :users, :duration
  end
end

class ChangeColumnCidrToInet < TestMigration
  def up
    add_column :users, :ip, :cidr
    change_column :users, :ip, :inet
  end

  def down
    remove_column :users, :ip
  end
end

class ChangeColumnInetToCidr < TestMigration
  def up
    add_column :users, :ip, :inet
    change_column :users, :ip, :cidr
  end

  def down
    remove_column :users, :ip
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

class ChangeColumnMissingTable < TestMigration
  def change
    change_column :missing, :properties, :string
  end
end

class ChangeColumnConstraint < TestMigration
  def change
    safety_assured do
      add_check_constraint :users, "name IS NOT NULL"
      add_check_constraint :users, "name = lower(name)"
      add_check_constraint :users, "credit_score > 0"
    end
    change_column :users, :name, :text
  end
end

class ChangeColumnOtherConstraints < TestMigration
  def change
    add_column :users, :new_name, :string
    safety_assured do
      add_check_constraint :users, "new_name IS NOT NULL"
      add_check_constraint :users, "credit_score > 0"
    end
    reversible do |direction|
      direction.up { change_column :users, :name, :text }
      direction.down { change_column :users, :name, :string }
    end
  end
end
