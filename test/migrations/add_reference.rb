class AddReference < TestMigration
  def change
    add_reference :users, :device, index: true
  end
end

class AddReferencePolymorphic < TestMigration
  def change
    add_reference :users, :device, polymorphic: true, index: true
  end
end

class AddReferenceNoIndex < TestMigration
  def change
    add_reference :users, :country, index: false
  end
end

class AddReferenceDefault < TestMigration
  def change
    add_reference :users, :ip
  end
end

class AddReferenceForeignKey < TestMigration
  def change
    add_reference :users, :device, foreign_key: true, index: false
  end
end

class AddReferenceForeignKeyValidateFalse < TestMigration
  def change
    add_reference :users, :device, foreign_key: {validate: false}, index: false
  end
end

class AddReferenceForeignKeyToTable < TestMigration
  def change
    add_reference :users, :device, foreign_key: {to_table: :users}, index: false
  end
end

class AddReferenceForeignKeyOnDelete < TestMigration
  def change
    add_reference :users, :device, foreign_key: {on_delete: :nullify}, index: false
  end
end

class AddReferenceConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    add_reference :users, :ip, index: {algorithm: :concurrently}
  end
end

class AddBelongsTo < TestMigration
  def change
    add_belongs_to :users, :device, index: true
  end
end

class AddReferenceExtraArguments < TestMigration
  def change
    add_reference :users, :device, :extra, index: true
  end
end
