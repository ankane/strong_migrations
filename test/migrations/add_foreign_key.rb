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

class AddForeignKeyColumn < TestMigration
  def change
    add_reference :users, :other_order, index: false
    add_foreign_key :users, :orders, column: "order_id"
    add_foreign_key :users, :orders, column: "other_order_id"
  end
end

class AddForeignKeyNoChecks < TestMigration
  def up
    safety_assured do
      begin
        execute "SET SESSION foreign_key_checks = 0"
        add_foreign_key :users, :orders
      ensure
        execute "SET SESSION foreign_key_checks = 1"
      end
    end
  end

  def down
    remove_foreign_key :users, :orders
  end
end
