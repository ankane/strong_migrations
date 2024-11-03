class RemoveColumn < TestMigration
  def change
    remove_column :users, :name, :string
  end
end

class RemoveColumns < TestMigration
  def change
    remove_columns :users, :name, :other
  end
end

class RemoveColumnsType < TestMigration
  def change
    remove_columns :users, :name, :other, type: :text
  end
end

class RemoveTimestamps < TestMigration
  def change
    remove_timestamps :users
  end
end

class RemoveReference < TestMigration
  def change
    remove_reference :users, :device
  end
end

class RemoveReferencePolymorphic < TestMigration
  def change
    remove_reference :users, :device, polymorphic: true
  end
end

class RemoveBelongsTo < TestMigration
  def change
    remove_belongs_to :users, :device
  end
end

class RemoveColumnNull < TestMigration
  def change
    remove_column :devices, :name, :string
  end
end

class RemoveColumnsNull < TestMigration
  def change
    remove_columns :devices, :name, :city, :country
  end
end
