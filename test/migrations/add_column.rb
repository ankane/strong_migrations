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
    add_column :users, :nice, :uuid, default: "gen_random_uuid()", null: false
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

class AddColumnDefaultUUIDSafe < TestMigration
  def change
    add_column :users, :nice, :uuid
    change_column_default :users, :nice, from: nil, to: "gen_random_uuid()"
  end
end

class AddColumnJson < TestMigration
  def change
    add_column :users, :properties, :json
  end
end

class AddColumnGeneratedStored < TestMigration
  def change
    add_column :users, :nice, :virtual, type: :string, as: "LOWER(city)", stored: true
  end
end

class AddColumnGeneratedVirtual < TestMigration
  def change
    add_column :users, :nice, :virtual, type: :string, as: "LOWER(city)"
  end
end

class AddColumnPrimaryKey < TestMigration
  def change
    add_column :users, :nice, :primary_key
  end
end

class AddColumnSerial < TestMigration
  def change
    add_column :users, :nice, :serial
  end
end

class AddColumnBigserial < TestMigration
  def change
    add_column :users, :nice, :bigserial
  end
end
