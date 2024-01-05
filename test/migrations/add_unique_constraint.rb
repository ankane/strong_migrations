class AddUniqueConstraint < TestMigration
  def change
    add_unique_constraint :users, :name
  end
end

class AddUniqueConstraintUsingIndex < TestMigration
  disable_ddl_transaction!

  def up
    add_index :users, :name, unique: true, algorithm: :concurrently
    add_unique_constraint :users, using_index: "index_users_on_name"
  end

  def down
    remove_unique_constraint :users, :name
  end
end

class AddUniqueConstraintNewTable < TestMigration
  def change
    create_table :new_users do |t|
      t.string :name
    end

    add_unique_constraint :new_users, :name
  end
end
