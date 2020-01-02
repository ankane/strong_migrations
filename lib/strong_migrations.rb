# dependencies
require "active_support"

# modules
require "strong_migrations/checker"
require "strong_migrations/database_tasks"
require "strong_migrations/migration"
require "strong_migrations/migration_helpers"
require "strong_migrations/version"

# integrations
require "strong_migrations/railtie" if defined?(Rails)

module StrongMigrations
  class Error < StandardError; end
  class UnsafeMigration < Error; end

  class << self
    attr_accessor :auto_analyze, :start_after, :checks, :error_messages,
      :target_postgresql_version, :enabled_checks, :lock_timeout, :statement_timeout
  end
  self.auto_analyze = false
  self.start_after = 0
  self.checks = []
  self.error_messages = {
    add_column_default:
"Adding a column with a non-null default causes the entire table to be rewritten.
Instead, add the column without a default value, then change the default.

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  def up
    %{add_command}
    %{change_command}
  end

  def down
    %{remove_command}
  end
end

Then backfill the existing rows in the Rails console or a separate migration with disable_ddl_transaction!.

class Backfill%{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{code}
  end
end%{append}",

    add_column_json:
"There's no equality operator for the json column type, which can
cause errors for existing SELECT DISTINCT queries. Use jsonb instead.",

    change_column:
"Changing the type of an existing column requires the entire
table and indexes to be rewritten. A safer approach is to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to the new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column",

    remove_column: "ActiveRecord caches attributes which causes problems
when removing columns. Be sure to ignore the column%{column_suffix}:

class %{model} < %{base_model}
  %{code}
end

Deploy the code, then wrap this step in a safety_assured { ... } block.

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  def change
    safety_assured { %{command} }
  end
end",

    rename_column:
"Renaming a column is dangerous. A safer approach is to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column",

    rename_table:
"Renaming a table is dangerous. A safer approach is to:

1. Create a new table. Don't forget to recreate indexes from the old table
2. Write to both tables
3. Backfill data from the old table to new table
4. Move reads from the old table to the new table
5. Stop writing to the old table
6. Drop the old table",

    add_reference:
"Adding an index non-concurrently locks the table. Instead, use:

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{command}
  end
end",

    add_index:
"Adding an index non-concurrently locks the table. Instead, use:

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{command}
  end
end",

    remove_index:
"Removing an index non-concurrently locks the table. Instead, use:

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{command}
  end
end",

    add_index_columns:
"Adding a non-unique index with more than three columns rarely improves performance.
Instead, start an index with columns that narrow down the results the most.",

    change_table:
"Strong Migrations does not support inspecting what happens inside a
change_table block, so cannot help you here. Please make really sure that what
you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block.",

    create_table:
"The force option will destroy existing tables.
If this is intended, drop the existing table first.
Otherwise, remove the force option.",

    execute:
"Strong Migrations does not support inspecting what happens inside an
execute call, so cannot help you here. Please make really sure that what
you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block.",

    change_column_null:
"Passing a default value to change_column_null runs a single UPDATE query,
which can cause downtime. Instead, backfill the existing rows in the
Rails console or a separate migration with disable_ddl_transaction!.

class Backfill%{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{code}
  end
end",

    change_column_null_postgresql:
"Setting NOT NULL on a column requires an AccessExclusiveLock,
which is expensive on large tables. Instead, we can use a constraint and
validate it in a separate step with a more agreeable RowShareLock.

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{command}
  end
end",

    add_foreign_key:
"New foreign keys are validated by default. This acquires an AccessExclusiveLock,
which is expensive on large tables. Instead, we can validate it in a separate step
with a more agreeable RowShareLock.

class %{migration_name} < ActiveRecord::Migration%{migration_suffix}
  disable_ddl_transaction!

  def change
    %{command}
  end
end",

    reversible_migrations:
"Migration is not reversible.",
  }
  self.enabled_checks = (error_messages.keys - [:remove_index, :reversible_migrations]).map { |k| [k, {}] }.to_h

  def self.add_check(&block)
    checks << block
  end

  def self.enable_check(check, start_after: nil)
    enabled_checks[check] = {start_after: start_after}
  end

  def self.disable_check(check)
    enabled_checks.delete(check)
  end

  def self.check_enabled?(check, version: nil)
    if enabled_checks[check]
      start_after = enabled_checks[check][:start_after] || StrongMigrations.start_after
      !version || version > start_after
    else
      false
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(StrongMigrations::Migration)
  ActiveRecord::Migration.include(StrongMigrations::MigrationHelpers)

  if defined?(ActiveRecord::Tasks::DatabaseTasks)
    ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(StrongMigrations::DatabaseTasks)
  end
end
