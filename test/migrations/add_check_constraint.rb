class AddCheckConstraint < TestMigration
  def change
    add_check_constraint :users, "credit_score > 0", name: 'users_credit_score_positive'
  end
end

class AddCheckConstraintSafe < TestMigration
  def change
    add_check_constraint :users, "credit_score > 0", validate: false
  end
end

class AddCheckConstraintValidateSameTransaction < TestMigration
  def change
    add_check_constraint :users, "credit_score > 0", name: "credit_check", validate: false
    validate_check_constraint :users, name: "credit_check"
  end
end

class AddCheckConstraintValidateNoTransaction < TestMigration
  disable_ddl_transaction!

  def change
    add_check_constraint :users, "credit_score > 0", name: "credit_check", validate: false
    validate_check_constraint :users, name: "credit_check"
  end
end

class AddCheckConstraintNewTable < TestMigration
  def change
    create_table :new_users do |t|
      t.string :name
    end

    add_check_constraint :new_users, "name IS NOT NULL"
  end
end

class AddCheckConstraintName < TestMigration
  def change
    add_check_constraint :users, "credit_score > 0", name: "credit_check"
  end
end

class AddCheckConstraintExtraArguments < TestMigration
  def change
    add_check_constraint :users, "credit_score > 0", :extra
  end
end
