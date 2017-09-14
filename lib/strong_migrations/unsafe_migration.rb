module StrongMigrations
  class UnsafeMigration < StandardError
    class Messages
      AddColumnDefault = <<~MSG
        Adding a column with a non-null default requires
        the entire table and indexes to be rewritten. Instead:

        1. Add the column without a default value
        2. Add the default value
        3. Commit the transaction
        4. Backfill the column
      MSG
      AddColumnJson = <<~MSG
        There's no equality operator for the json column type.
        Replace all calls to uniq with a custom scope.

          scope :uniq_on_id, -> { select(\"DISTINCT ON (your_table.id) your_table.*\") }

        Once it's deployed, wrap this step in a safety_assured { ... } block.
      MSG
      ChangeColumn = <<~MSG
        Changing the type of an existing column requires
        the entire table and indexes to be rewritten.

        If you really have to:

        1. Create a new column
        2. Write to both columns
        3. Backfill data from the old column to the new column
        4. Move reads from the old column to the new column
        5. Stop writing to the old column
        6. Drop the old column
      MSG
      RemoveColumn = <<~MSG
        ActiveRecord caches attributes which causes problems
        when removing columns. Be sure to ignored the column:

        class User
          def self.columns
            super.reject { |c| c.name == \"some_column\" }
          end
        end

        Once it's deployed, wrap this step in a safety_assured { ... } block.
      MSG
      RenameColumn = <<~MSG
        If you really have to:

        1. Create a new column
        2. Write to both columns
        3. Backfill data from the old column to new column
        4. Move reads from the old column to the new column
        5. Stop writing to the old column
        6. Drop the old column
      MSG
      RenameTable = <<~MSG
        If you really have to:

        1. Create a new table
        2. Write to both tables
        3. Backfill data from the old table to new table
        4. Move reads from the old table to the new table
        5. Stop writing to the old table
        6. Drop the old table
      MSG
      AddReference = <<~MSG
        Adding a non-concurrent index locks the table. Instead, use:

          def change
            add_reference :users, :reference, index: false
            commit_db_transaction
            add_index :users, :reference_id, algorithm: :concurrently
          end
      MSG
      AddIndex = <<~MSG
        Adding a non-concurrent index locks the table. Instead, use:

          def change
            commit_db_transaction
            add_index :users, :some_column, algorithm: :concurrently
          end
      MSG
      AddIndexColumns = <<~MSG
        Adding an index with more than three columns only helps on extremely large tables.

        If you're sure this is what you want, wrap it in a safety_assured { ... } block.
      MSG
      ChangeTable = <<~MSG
        The strong_migrations gem does not support inspecting what happens inside a
        change_table block, so cannot help you here. Please make really sure that what
        you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block.
      MSG
      CreateTable = <<~MSG
        The force option will destroy existing tables.
        If this is intended, drop the existing table first.
        Otherwise, remove the option.
      MSG
      Execute = <<~MSG
        The strong_migrations gem does not support inspecting what happens inside an
        execute call, so cannot help you here. Please make really sure that what
        you're doing is safe before proceeding, then wrap it in a safety_assured { ... } block.
      MSG
    end
  end
end
