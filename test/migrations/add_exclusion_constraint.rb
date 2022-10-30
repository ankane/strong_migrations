class AddExclusionConstraint < TestMigration
  def change
    add_exclusion_constraint :users, "credit_score WITH =", using: :gist
  end
end

class AddExclusionConstraintNewTable < TestMigration
  def change
    create_table :new_users do |t|
      t.decimal :credit_score, precision: 10, scale: 5
    end

    add_exclusion_constraint :new_users, "credit_score WITH =", using: :gist
  end
end
