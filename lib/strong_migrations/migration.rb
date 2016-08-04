module StrongMigrations
  module Migration
    def safety_assured
      previous_value = @safe
      @safe = true
      yield
    ensure
      @safe = previous_value
    end

    def migrate(direction)
      @direction = direction
      super
    end

    def method_missing(method, *args, &block)
      unless @safe || ENV["SAFETY_ASSURED"] || is_a?(ActiveRecord::Schema) || @direction == :down
        case method
        when :remove_column
          raise_error :remove_column
        when :remove_timestamps
          raise_error :remove_column
        when :change_table
          raise_error :change_table
        when :rename_table
          raise_error :rename_table
        when :rename_column
          raise_error :rename_column
        when :add_index
          columns = args[1]
          if columns.is_a?(Array) && columns.size > 3
            raise_error :add_index_columns
          end
          options = args[2]
          if %w(PostgreSQL PostGIS).include?(connection.adapter_name) && !(options && options[:algorithm] == :concurrently)
            raise_error :add_index
          end
        when :remove_index
          raise_error :remove_index
        when :add_column
          type = args[2]
          options = args[3]
          raise_error :add_column_default if options && !options[:default].nil?
          raise_error :add_column_json if type.to_s == "json"
        when :change_column
          raise_error :change_column
        end
      end

      super
    end

    private

    def raise_error(message_key)
      message =
        case message_key
        when :add_column_default
"Adding a column with a non-null default requires
the entire table and indexes to be rewritten. Instead:

1. Add the column without a default value
2. Commit the transaction
3. Backfill the column
4. Add the default value"
        when :add_column_json
"There's no equality operator for the json column type.
Replace all calls to uniq with a custom scope.

  scope :uniq_on_id, -> { select(\"DISTINCT ON (your_table.id) your_table.*\") }

Once it's deployed, wrap this step in a safety_assured { ... } block."
        when :change_column
"Changing the type of an existing column requires
the entire table and indexes to be rewritten.

If you really have to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to the new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column"
        when :remove_column
"ActiveRecord caches attributes which causes problems
when removing columns. Be sure to ignored the column:

class User
  def self.columns
    super.reject { |c| c.name == \"some_column\" }
  end
end

Once it's deployed, wrap this step in a safety_assured { ... } block."
        when :rename_column
"If you really have to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column"
        when :rename_table
"If you really have to:

1. Create a new table
2. Write to both tables
3. Backfill data from the old table to new table
4. Move reads from the old table to the new table
5. Stop writing to the old table
6. Drop the old table"
        when :add_index
"Adding a non-concurrent index locks the table. Instead, use:

  def change
    commit_db_transaction
    add_index :users, :some_column, algorithm: :concurrently
  end"
        when :remove_index
"If you are looking to change an index. Instead, use:

  def change
    commit_db_transaction
    add_index :users, :some_column, options
    safety_assured { remove_index :users, name: old_index_name }
  end

If you are looking to delete an unused index, wrap this step in a safety_assured { ... } block."
        when :add_index_columns
"Adding an index with more than three columns only helps on extremely large tables.

If you're sure this is what you want, wrap it in a safety_assured { ... } block."
        when :change_table
"The strong_migrations gem does not support inspecting what happens inside a
change_table block, so cannot help you here. Please make really sure that what
you're doing is safe before proceding, then wrap it in a safety_assured { ... } block."
        end

      wait_message = '
 __          __     _____ _______ _
 \ \        / /\   |_   _|__   __| |
  \ \  /\  / /  \    | |    | |  | |
   \ \/  \/ / /\ \   | |    | |  | |
    \  /\  / ____ \ _| |_   | |  |_|
     \/  \/_/    \_\_____|  |_|  (_)

'

      raise StrongMigrations::UnsafeMigration, "#{wait_message}#{message}\n"
    end
  end
end
