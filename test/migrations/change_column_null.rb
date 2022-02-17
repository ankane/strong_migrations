class ChangeColumnNull < TestMigration
  def change
    change_column_null :users, :name, false
  end
end

class ChangeColumnNullConstraint < TestMigration
  def up
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "test" CHECK ("name" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "test"'
    end
    change_column_null :users, :name, false
  end

  def down
    execute 'ALTER TABLE "users" DROP CONSTRAINT "test"'
    change_column_null :users, :name, true
  end
end

class ChangeColumnNullConstraintMethods < TestMigration
  disable_ddl_transaction!

  def up
    add_check_constraint :users, "name IS NOT NULL", name: "test", validate: false
    validate_check_constraint :users, name: "test"
    change_column_null :users, :name, false
    remove_check_constraint :users, name: "test"
  end

  def down
    change_column_null :users, :name, true
  end
end

class ChangeColumnNullConstraintUnvalidated < TestMigration
  def up
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "test" CHECK ("name" IS NOT NULL) NOT VALID'
    end
    change_column_null :users, :name, false
  end

  def down
    execute 'ALTER TABLE "users" DROP CONSTRAINT "test"'
    change_column_null :users, :name, true
  end
end

class ChangeColumnNullConstraintDefault < TestMigration
  def up
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "test" CHECK ("name" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "test"'
    end
    change_column_null :users, :name, false, "Andy"
  end

  def down
    execute 'ALTER TABLE "users" DROP CONSTRAINT "test"'
    change_column_null :users, :name, true
  end
end

class ChangeColumnNullDefault < TestMigration
  def change
    change_column_null :users, :name, false, "Andy"
  end
end

class ChangeColumnNullQuoted < TestMigration
  def up
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "test" CHECK ("interval" IS NOT NULL) NOT VALID'
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "test"'
    end
    change_column_null :users, :interval, false
  end

  def down
    execute 'ALTER TABLE "users" DROP CONSTRAINT "test"'
    change_column_null :users, :interval, true
  end
end
