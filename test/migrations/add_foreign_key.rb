class AddForeignKey < TestMigration
  def change
    add_foreign_key :users, :orders
  end
end

class AddForeignKeySafe < TestMigration
  def change
    add_foreign_key :users, :orders, validate: false
  end
end

class AddForeignKeyValidateSameTransaction < TestMigration
  def change
    add_foreign_key :users, :orders, validate: false
    validate_foreign_key :users, :orders
  end
end

class AddForeignKeyValidateNoTransaction < TestMigration
  disable_ddl_transaction!

  def change
    add_foreign_key :users, :orders, validate: false
    validate_foreign_key :users, :orders
  end
end

class AddForeignKeyExtraArguments < TestMigration
  def change
    add_foreign_key :users, :orders, :extra
  end
end

class AddForeignKeyName < TestMigration
  def change
    add_foreign_key :users, :orders, name: "fk1"
    add_foreign_key :users, :orders, name: "fk2"
  end
end
