require "active_support"

require "strong_migrations/database_tasks"
require "strong_migrations/migration"
require "strong_migrations/railtie" if defined?(Rails)
require "strong_migrations/unsafe_migration"
require "strong_migrations/version"

module StrongMigrations
  class << self
    attr_accessor :auto_analyze, :start_after, :checks, :error_messages
  end
  self.auto_analyze = false
  self.start_after = 0
  self.checks = []
  self.error_messages = {
    add_column_default:
"Adding a column with a non-null default causes
the entire table to be rewritten.

Instead, add the column without a default value,
then change the default.

  def up
    add_column %{table}, %{column}, %{type}%{options}
    change_column_default %{table}, %{column}, %{default}
  end

  def down
    remove_column %{table}, %{column}
  end

More info: https://github.com/ankane/strong_migrations#adding-a-column-with-a-default-value",

    add_column_json:
"There's no equality operator for the json column type, which
causes issues for SELECT DISTINCT queries. Use jsonb instead.",

    add_column_json_legacy:
"There's no equality operator for the json column type, which.
causes issues for SELECT DISTINCT queries.
Replace all calls to uniq with a custom scope.

class %{model} < ApplicationRecord
  scope :uniq_on_id, -> { select('DISTINCT ON (%{table}.id) %{table}.*') }
end

Once it's deployed, wrap this step in a safety_assured { ... } block.",

    change_column:
"Changing the type of an existing column requires
the entire table and indexes to be rewritten.

If you really have to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to the new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column",

    remove_column: "ActiveRecord caches attributes which causes problems
when removing columns. Be sure to ignore the column:

class %{model} < ApplicationRecord
  self.ignored_columns = [%{column}]
end

Once that's deployed, wrap this step in a safety_assured { ... } block.

More info: https://github.com/ankane/strong_migrations#removing-a-column",

    rename_column:
"If you really have to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column",

    rename_table:
"If you really have to:

1. Create a new table
2. Write to both tables
3. Backfill data from the old table to new table
4. Move reads from the old table to the new table
5. Stop writing to the old table
6. Drop the old table",

    add_reference:
"Adding a non-concurrent index locks the table. Instead, use:

  disable_ddl_transaction!

  def change
    %{command} %{table}, %{reference}, index: false%{options}
    add_index %{table}, %{column}, algorithm: :concurrently
  end",

    add_index:
"Adding a non-concurrent index locks the table. Instead, use:

  disable_ddl_transaction!

  def change
    add_index %{table}, %{column}, algorithm: :concurrently%{options}
  end",

    add_index_columns:
"Adding an index with more than three columns only helps on extremely large tables.

If you're sure this is what you want, wrap it in a safety_assured { ... } block.",

    change_table:
"Strong Migrations does not support inspecting what happens inside a
change_table block, so cannot help you here. Please make really sure that what
you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block.",

    create_table:
"The force option will destroy existing tables.
If this is intended, drop the existing table first.
Otherwise, remove the option.",

    execute:
"Strong Migrations does not support inspecting what happens inside an
execute call, so cannot help you here. Please make really sure that what
you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block.",

   change_column_null:
"The last argument replaces existing NULLs with another value.
This runs a single UPDATE query, which can cause downtime.
Backfill NULLs manually in batches instead.

More info: https://github.com/ankane/strong_migrations#backfilling-data"
  }

  def self.add_check(&block)
    checks << block
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(StrongMigrations::Migration)

  if ActiveRecord::VERSION::MAJOR < 5
    StrongMigrations.error_messages[:remove_column] = "ActiveRecord caches attributes which causes problems
when removing columns. Be sure to ignore the column:

class %{model} < ActiveRecord::Base
  def self.columns
    super.reject { |c| c.name == %{column} }
  end
end

Once that's deployed, wrap this step in a safety_assured { ... } block.

More info: https://github.com/ankane/strong_migrations#removing-a-column"
  end

  if defined?(ActiveRecord::Tasks::DatabaseTasks)
    ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(StrongMigrations::DatabaseTasks)
  end
end
