module StrongMigrations
  module MigrationHelpers

    # Adds a foreign key with only minimal locking on the tables involved.
    #
    # This method only requires minimal locking
    #
    # from_table - The table containing the foreign key.
    # to_table - The table the key points to.
    # column - The name of the column to create the foreign key on.
    # on_delete - The action to perform when associated data is removed,
    #             defaults to "CASCADE".
    # name - The name of the foreign key.
    # TODO: deprecate this in favor of `add_foreign_key ..., validate: false`
    # after depending on activerecord >= 5.2
    def add_foreign_key_concurrently(from_table, to_table, column:, on_delete: :cascade, name: nil)
      ensure_not_in_transaction(__method__)

      options = {
        column: column,
        on_delete: on_delete,
        name: name || concurrent_foreign_key_name(from_table, column)
      }

      # Using NOT VALID allows us to create a key without immediately
      # validating it. This means we keep the ALTER TABLE lock only for a
      # short period of time. The key _is_ enforced for any newly created
      # data.
      safety_assured do
        execute <<-EOF.strip_heredoc
        ALTER TABLE #{from_table}
        ADD CONSTRAINT #{options[:name]}
        FOREIGN KEY (#{options[:column]})
        REFERENCES #{to_table} (id)
        #{on_delete_statement(options[:on_delete])}
        NOT VALID;
        EOF

        # Validate the existing constraint. This can potentially take a very
        # long time to complete, but fortunately does not lock the from_table table
        # while running.
        #
        # Note this is a no-op in case the constraint is VALID already
        execute("ALTER TABLE #{from_table} VALIDATE CONSTRAINT #{options[:name]};")
      end
    end

    # Updates the value of a column in batches.
    #
    # This method updates the table in batches of 5% of the total row count.
    # A `batch_size` option can also be passed to set this to a fixed number.
    # This method will continue updating rows until no rows remain.
    #
    # When given a block this method will yield two values to the block:
    #
    # 1. An instance of `Arel::Table` for the table that is being updated.
    # 2. The query to run as an Arel object.
    #
    # By supplying a block one can add extra conditions to the queries being
    # executed. Note that the same block is used for _all_ queries.
    #
    # Example:
    #
    #     update_column_in_batches(:projects, :foo, 10) do |table, query|
    #       query.where(table[:some_column].eq("hello"))
    #     end
    #
    # This would result in this method updating only rows where
    # `projects.some_column` equals "hello".
    #
    # table - The name of the table.
    # column - The name of the column to update.
    # value - The value for the column.
    #
    # The `value` argument is typically a literal. To perform a computed
    # update, an Arel literal can be used instead:
    #
    #     update_value = Arel.sql("bar * baz")
    #
    #     update_column_in_batches(:projects, :foo, update_value) do |table, query|
    #       query.where(table[:some_column].eq("hello"))
    #     end
    #
    def update_column_in_batches(table, column, value, batch_size: nil)
      ensure_not_in_transaction(__method__)

      table = Arel::Table.new(table)

      count_arel = table.project(Arel.star.count.as("count"))
      count_arel = yield table, count_arel if block_given?

      total = exec_query(count_arel.to_sql).to_hash.first["count"].to_i

      return if total == 0

      if batch_size.nil?
        # Update in batches of 5% until we run out of any rows to update.
        batch_size = ((total / 100.0) * 5.0).ceil
        max_size = 1000

        # The upper limit is 1000 to ensure we don't lock too many rows.
        batch_size = max_size if batch_size > max_size
      end

      start_arel = table.project(table[:id]).order(table[:id].asc).take(1)
      start_arel = yield table, start_arel if block_given?
      start_id = exec_query(start_arel.to_sql).to_hash.first["id"].to_i

      loop do
        stop_arel = table.project(table[:id])
          .where(table[:id].gteq(start_id))
          .order(table[:id].asc)
          .take(1)
          .skip(batch_size)

        stop_arel = yield table, stop_arel if block_given?
        stop_row = exec_query(stop_arel.to_sql).to_hash.first

        update_arel = Arel::UpdateManager.new
          .table(table)
          .set([[table[column], value]])
          .where(table[:id].gteq(start_id))

        if stop_row
          stop_id = stop_row["id"].to_i
          start_id = stop_id
          update_arel = update_arel.where(table[:id].lt(stop_id))
        end

        update_arel = yield table, update_arel if block_given?

        execute(update_arel.to_sql)

        # There are no more rows left to update.
        break unless stop_row
      end
    end

    # Adds a column with a default value without locking an entire table.
    #
    # This method runs the following steps:
    #
    # 1. Add the column with a default value of NULL.
    # 2. Change the default value of the column to the specified value.
    # 3. Update all existing rows in batches.
    # 4. Set a `NOT NULL` constraint on the column if desired (the default).
    #
    # These steps ensure a column can be added to a large and commonly used
    # table without locking the entire table for the duration of the table
    # modification.
    #
    # table - The name of the table to update.
    # column - The name of the column to add.
    # type - The column type (e.g. `:integer`).
    # default - The default value for the column.
    # limit - Sets a column limit. For example, for :integer, the default is
    #         4-bytes. Set `limit: 8` to allow 8-byte integers.
    # allow_null - When set to `true` the column will allow NULL values, the
    #              default is to not allow NULL values.
    def add_column_with_default(table, column, type, default:, limit: nil, allow_null: false)
      ensure_not_in_transaction(__method__)

      transaction do
        if limit
          add_column(table, column, type, default: nil, limit: limit)
        else
          add_column(table, column, type, default: nil)
        end

        # Changing the default before the update ensures any newly inserted
        # rows already use the proper default value.
        change_column_default(table, column, default)
      end

      begin
        default_after_type_cast = connection.type_cast(default, column_for(table, column))
        update_column_in_batches(table, column, default_after_type_cast)

        unless allow_null
          safety_assured { change_column_null(table, column, false) }
        end
      # We want to rescue _all_ exceptions here, even those that don't inherit
      # from StandardError.
      rescue Exception => error
        safety_assured { remove_column(table, column) }

        raise error
      end
    end

    # Renames a column without requiring downtime.
    #
    # Concurrent renames work by using database triggers to ensure both the
    # old and new column are in sync. However, this method will _not_ remove
    # the triggers or the old column automatically; this needs to be done
    # manually in a post-deployment migration. This can be done using the
    # method `cleanup_after_rename_column_concurrently`.
    #
    # table - The name of the database table containing the column.
    # old - The old column name.
    # new - The new column name.
    # type - The type of the new column. If no type is given the old column's
    #        type is used.
    def rename_column_concurrently(table, old, new, type: nil)
      ensure_not_in_transaction(__method__)

      safety_assured do
        check_trigger_permissions(table)
        create_column_from(table, old, new, type: type)
        install_rename_triggers(table, old, new)
      end
    end

    # Reverses operations performed by rename_column_concurrently.
    #
    # This method takes care of removing previously installed triggers as well
    # as removing the new column.
    #
    # table - The name of the database table.
    # old - The name of the old column.
    # new - The name of the new column.
    def undo_rename_column_concurrently(table, old, new)
      safety_assured do
        trigger_name = rename_trigger_name(table, old, new)
        check_trigger_permissions(table)
        remove_rename_triggers_for_postgresql(table, trigger_name)
        remove_column(table, new)
      end
    end

    # Cleans up a concurrent column name.
    #
    # This method takes care of removing previously installed triggers as well
    # as removing the old column.
    #
    # table - The name of the database table.
    # old - The name of the old column.
    # new - The name of the new column.
    def cleanup_after_rename_column_concurrently(table, old, new)
      safety_assured do
        trigger_name = rename_trigger_name(table, old, new)
        check_trigger_permissions(table)
        remove_rename_triggers_for_postgresql(table, trigger_name)
        remove_column(table, old)
      end
    end

    # Reverses the operations performed by cleanup_after_rename_column_concurrently.
    #
    # This method adds back the old_column removed
    # by cleanup_after_rename_column_concurrently.
    # It also adds back the (old_column > new_column) trigger that is removed
    # by cleanup_after_rename_column_concurrently.
    #
    # table - The name of the database table containing the column.
    # old - The old column name.
    # new - The new column name.
    # type - The type of the old column. If no type is given the new column's
    #        type is used.
    def undo_cleanup_after_rename_column_concurrently(table, old, new, type: nil)
      ensure_not_in_transaction(__method__)

      safety_assured do
        check_trigger_permissions(table)
        create_column_from(table, new, old, type: type)
        install_rename_triggers(table, old, new)
      end
    end

    # Changes the type of a column concurrently.
    #
    # table - The table containing the column.
    # column - The name of the column to change.
    # new_type - The new column type.
    def change_column_type_concurrently(table, column, new_type)
      temp_column = "#{column}_for_type_change"
      rename_column_concurrently(table, column, temp_column, type: new_type)
    end

    # Performs cleanup of a concurrent type change.
    #
    # table - The table containing the column.
    # column - The name of the column to change.
    # new_type - The new column type.
    def cleanup_after_change_column_type_concurrently(table, column)
      temp_column = "#{column}_for_type_change"

      transaction do
        # This has to be performed in a transaction as otherwise we might have
        # inconsistent data.
        cleanup_after_rename_column_concurrently(table, column, temp_column)
        rename_column(table, temp_column, column)
      end
    end

    private

    def ensure_not_in_transaction(method_name)
      if transaction_open?
        raise <<~ERROR
          `#{method_name}` cannot be run inside a transaction.

          You can disable transactions by calling `disable_ddl_transaction!` in the body of
          your migration class
        ERROR
      end
    end

    # Removes the triggers used for renaming a PostgreSQL column concurrently.
    def remove_rename_triggers_for_postgresql(table, trigger)
      execute("DROP TRIGGER IF EXISTS #{trigger} ON #{table}")
      execute("DROP FUNCTION IF EXISTS #{trigger}()")
    end

    # Returns the (base) name to use for triggers when renaming columns.
    def rename_trigger_name(table, old, new)
      "trigger_" + Digest::SHA256.hexdigest("#{table}_#{old}_#{new}").first(12)
    end

    def check_trigger_permissions(table)
      # We _must not_ use quote_table_name as this will produce double
      # quotes on PostgreSQL and for "has_table_privilege" we need single
      # quotes.
      quoted_table = connection.quote(table)
      has_privilege =
        begin
          result = exec_query("SELECT has_table_privilege(#{quoted_table}, 'TRIGGER')")
          result.rows[0][0]
        rescue ActiveRecord::StatementInvalid
          # This error is raised when using a non-existing table name. In this
          # case we just want to return false as a user technically can't
          # create triggers for such a table.
          false
        end

      raise "Your database user is not allowed to create, drop, or execute triggers on the table #{table}." unless has_privilege
    end

    # Returns the name for a concurrent foreign key.
    #
    # PostgreSQL constraint names have a limit of 63 bytes. The logic used
    # here is based on Rails' foreign_key_name() method, which unfortunately
    # is private so we can't rely on it directly.
    def concurrent_foreign_key_name(table, column)
      identifier = "#{table}_#{column}_fk"
      hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

      "fk_#{hashed_identifier}"
    end

    def on_delete_statement(on_delete)
      case on_delete
      when nil, ""  then ""
      when :nullify then "ON DELETE SET NULL"
      else "ON DELETE #{on_delete.upcase}"
      end
    end

    # Installs triggers in a table that keep a new column in sync with an old
    # one.
    #
    # table - The name of the table to install the trigger in.
    # old_column - The name of the old column.
    # new_column - The name of the new column.
    def install_rename_triggers(table, old_column, new_column)
      trigger_name = rename_trigger_name(table, old_column, new_column)
      quoted_table = quote_table_name(table)
      quoted_old = quote_column_name(old_column)
      quoted_new = quote_column_name(new_column)

      install_rename_triggers_for_postgresql(
        trigger_name,
        quoted_table,
        quoted_old,
        quoted_new
      )
    end

    # Performs a concurrent column rename when using PostgreSQL.
    def install_rename_triggers_for_postgresql(trigger, table, old, new)
      execute <<-EOF.strip_heredoc
      CREATE OR REPLACE FUNCTION #{trigger}()
      RETURNS trigger AS
      $BODY$
      BEGIN
        NEW.#{new} := NEW.#{old};
        RETURN NEW;
      END;
      $BODY$
      LANGUAGE 'plpgsql'
      VOLATILE
      EOF

      execute <<-EOF.strip_heredoc
      DROP TRIGGER IF EXISTS #{trigger}
      ON #{table}
      EOF

      execute <<-EOF.strip_heredoc
      CREATE TRIGGER #{trigger}
      BEFORE INSERT OR UPDATE
      ON #{table}
      FOR EACH ROW
      EXECUTE PROCEDURE #{trigger}()
      EOF
    end

    def create_column_from(table, old, new, type: nil)
      old_col = column_for(table, old)
      new_type = type || old_col.type

      add_column(table, new, new_type,
                 limit: old_col.limit,
                 precision: old_col.precision,
                 scale: old_col.scale)

      # We set the default value _after_ adding the column so we don't end up
      # updating any existing data with the default value. This isn't
      # necessary since we copy over old values further down.
      change_column_default(table, new, old_col.default) unless old_col.default.nil?

      update_column_in_batches(table, new, Arel::Table.new(table)[old])

      change_column_null(table, new, false) unless old_col.null

      copy_indexes(table, old, new)
      copy_foreign_keys(table, old, new)
    end

    # Returns the column for the given table and column name.
    def column_for(table, name)
      name = name.to_s

      columns(table).find { |column| column.name == name }
    end

    # Copies all indexes for the old column to a new column.
    #
    # table - The table containing the columns and indexes.
    # old - The old column.
    # new - The new column.
    def copy_indexes(table, old, new)
      old = old.to_s
      new = new.to_s

      indexes_for(table, old).each do |index|
        new_columns = index.columns.map do |column|
          column == old ? new : column
        end

        # This is necessary as we can't properly rename indexes such as
        # "ci_taggings_idx".
        unless index.name.include?(old)
          raise "The index #{index.name} can not be copied as it does not "\
            "mention the old column. You have to rename this index manually first."
        end

        name = index.name.gsub(old, new)

        options = {
          unique: index.unique,
          name: name,
          length: index.lengths,
          order: index.orders
        }

        options[:using] = index.using if index.using
        options[:where] = index.where if index.where

        unless index.opclasses.blank?
          opclasses = index.opclasses.dup

          # Copy the operator classes for the old column (if any) to the new
          # column.
          opclasses[new] = opclasses.delete(old) if opclasses[old]

          options[:opclasses] = opclasses
        end

        add_index_concurrently(table, new_columns, options)
      end
    end

    # Returns an Array containing the indexes for the given column
    def indexes_for(table, column)
      column = column.to_s

      indexes(table).select { |index| index.columns.include?(column) }
    end

    # Copies all foreign keys for the old column to the new column.
    #
    # table - The table containing the columns and indexes.
    # old - The old column.
    # new - The new column.
    def copy_foreign_keys(table, old, new)
      foreign_keys_for(table, old).each do |fk|
        add_foreign_key_concurrently(fk.from_table,
                                   fk.to_table,
                                   column: new,
                                   on_delete: fk.on_delete)
      end
    end

    # Returns an Array containing the foreign keys for the given column.
    def foreign_keys_for(table, column)
      column = column.to_s

      foreign_keys(table).select { |fk| fk.column == column }
    end
  end
end
