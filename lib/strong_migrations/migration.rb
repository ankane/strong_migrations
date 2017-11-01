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
      unless @safe || ENV["SAFETY_ASSURED"] || is_a?(ActiveRecord::Schema) || @direction == :down || version_safe?
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
          options = args[2] || {}
          if postgresql? && options[:algorithm] != :concurrently && !@new_tables.to_a.include?(args[0].to_s)
            raise_error :add_index
          end
        when :add_column
          type = args[2]
          options = args[3] || {}
          raise_error :add_column_default unless options[:default].nil?
          raise_error :add_column_json if type.to_s == "json"
        when :change_column
          raise_error :change_column
        when :create_table
          options = args[1] || {}
          raise_error :create_table if options[:force]
        when :add_reference
          options = args[2] || {}
          index_value = options.fetch(:index, ActiveRecord::VERSION::MAJOR >= 5 ? true : false)
          if postgresql? && index_value
            raise_error :add_reference
          end
        when :execute
          raise_error :execute
        end
      end

      if method == :create_table
        (@new_tables ||= []) << args[0].to_s
      end

      result = super

      if StrongMigrations.auto_analyze && postgresql? && method == :add_index
        connection.execute "ANALYZE VERBOSE #{connection.quote_table_name(args[0])}"
      end

      result
    end

    private

    def postgresql?
      %w(PostgreSQL PostGIS).include?(connection.adapter_name)
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def raise_error(message_key)
      message =
        case message_key
        when :add_column_default
"Adding a column with a non-null default requires
the entire table and indexes to be rewritten. Instead:

1. Add the column without a default value
2. Add the default value
3. Commit the transaction
4. Backfill the column"
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
          if ActiveRecord::VERSION::MAJOR >= 5
"ActiveRecord caches attributes which causes problems
when removing columns. Be sure to ignore the column:

class User
  self.ignored_columns = %w(some_column)
end

Once that's deployed, wrap this step in a safety_assured { ... } block."
          else
"ActiveRecord caches attributes which causes problems
when removing columns. Be sure to ignore the column:

class User
  def self.columns
    super.reject { |c| c.name == \"some_column\" }
  end
end

Once that's deployed, wrap this step in a safety_assured { ... } block."
          end
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
        when :add_reference
"Adding a non-concurrent index locks the table. Instead, use:

  def change
    add_reference :users, :reference, index: false
    commit_db_transaction
    add_index :users, :reference_id, algorithm: :concurrently
  end"
        when :add_index
"Adding a non-concurrent index locks the table. Instead, use:

  def change
    commit_db_transaction
    add_index :users, :some_column, algorithm: :concurrently
  end"
        when :add_index_columns
"Adding an index with more than three columns only helps on extremely large tables.

If you're sure this is what you want, wrap it in a safety_assured { ... } block."
        when :change_table
"The strong_migrations gem does not support inspecting what happens inside a
change_table block, so cannot help you here. Please make really sure that what
you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block."
        when :create_table
"The force option will destroy existing tables.
If this is intended, drop the existing table first.
Otherwise, remove the option."
        when :execute
"The strong_migrations gem does not support inspecting what happens inside an
execute call, so cannot help you here. Please make really sure that what
you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block."
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
