module StrongMigrations
  module MigrationHelpers
    include Util

    def add_foreign_key_safely(from_table, to_table, **options)
      ensure_postgresql(__method__)
      ensure_not_in_transaction(__method__)

      reversible do |dir|
        dir.up do
          if ActiveRecord::VERSION::STRING >= "5.2"
            add_foreign_key(from_table, to_table, options.merge(validate: false))
            validate_foreign_key(from_table, to_table)
          else
            options = connection.foreign_key_options(from_table, to_table, options)
            fk_name, column, primary_key = options.values_at(:name, :column, :primary_key)
            primary_key ||= "id"

            statement = ["ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s)"]
            statement << on_delete_update_statement(:delete, options[:on_delete]) if options[:on_delete]
            statement << on_delete_update_statement(:update, options[:on_update]) if options[:on_update]
            statement << "NOT VALID"

            safety_assured do
              execute quote_identifiers(statement.join(" "), [from_table, fk_name, column, to_table, primary_key])
              execute quote_identifiers("ALTER TABLE %s VALIDATE CONSTRAINT %s", [from_table, fk_name])
            end
          end
        end

        dir.down do
          remove_foreign_key(from_table, to_table)
        end
      end
    end

    def add_null_constraint_safely(table_name, column_name, name: nil)
      ensure_postgresql(__method__)
      ensure_not_in_transaction(__method__)

      reversible do |dir|
        dir.up do
          name ||= null_constraint_name(table_name, column_name)

          safety_assured do
            execute quote_identifiers("ALTER TABLE %s ADD CONSTRAINT %s CHECK (%s IS NOT NULL) NOT VALID", [table_name, name, column_name])
            execute quote_identifiers("ALTER TABLE %s VALIDATE CONSTRAINT %s", [table_name, name])
          end
        end

        dir.down do
          remove_null_constraint_safely(table_name, column_name)
        end
      end
    end

    # removing constraints is safe, but this method is safe to reverse as well
    def remove_null_constraint_safely(table_name, column_name, name: nil)
      # could also ensure in transaction so it can be reversed
      # but that's more of a concern for a reversible migrations check
      ensure_postgresql(__method__)

      reversible do |dir|
        dir.up do
          name ||= null_constraint_name(table_name, column_name)

          safety_assured do
            execute quote_identifiers("ALTER TABLE %s DROP CONSTRAINT %s", [table_name, name])
          end
        end

        dir.down do
          add_null_constraint_safely(table_name, column_name)
        end
      end
    end

    def add_column_safely(table_name, column_name, type, **options)
      ensure_postgresql(__method__)
      ensure_not_in_transaction(__method__)

      default = options.delete(:default)

      if postgresql_version >= 110000 || default.nil?
        add_column(table_name, column_name, options)
      else
        reversible do |dir|
          dir.up do
            transaction do
              add_column(table_name, column_name, type, default: nil, **options)
              change_column_default(table_name, column_name, default)
            end

            default_after_type_cast = connection.type_cast(default)
            backfill_column_safely(table_name, column_name, default_after_type_cast)

            allow_null = options[:null]
            add_null_constraint_safely(table_name, column_name) unless allow_null
          end

          dir.down do
            remove_column(table_name, column_name)
          end
        end
      end
    end

    def backfill_column_safely(table_name, column_name, value, batch_size: 1000)
      ensure_not_in_transaction(__method__)

      table = Arel::Table.new(table_name)
      count_arel = table.project(Arel.star.count.as("count"))
      total = connection.exec_query(count_arel.to_sql).first["count"]

      return if total == 0

      primary_key = connection.primary_key(table_name)

      start_arel = table
        .project(table[primary_key])
        .order(table[primary_key].asc)
        .take(1)

      start_pk = connection.exec_query(start_arel.to_sql).first[primary_key]

      loop do
        finish_arel = table
          .project(table[primary_key])
          .where(table[primary_key].gteq(start_pk))
          .order(table[primary_key].asc)
          .skip(batch_size)
          .take(1)

        finish_result = connection.exec_query(finish_arel.to_sql).first

        update_arel = Arel::UpdateManager.new
          .table(table)
          .set([[table[column_name], value]])
          .where(table[primary_key].gteq(start_pk))

        if finish_result
          finish_pk = finish_result[primary_key]
          update_arel = update_arel.where(table[primary_key].lt(finish_pk))
          start_pk = finish_pk
        end

        safety_assured { execute(update_arel.to_sql) }

        break unless finish_pk
      end
    end

    def rename_column_safely(table_name, old, new, options = {})
      if !postgresql? && !mysql?
        raise StrongMigrations::Error, "`#{__method__}` is intended for Postgres and Mysql only"
      end

      ensure_not_in_transaction(__method__)
      ensure_trigger_privileges(table_name)

      reversible do |dir|
        dir.up do
          copy_column(table_name, old, new, options)
          safety_assured { create_column_rename_triggers(table_name, old, new) }
        end

        dir.down do
          trigger_name = rename_column_trigger_name(table_name, old, new)

          safety_assured do
            remove_column_rename_triggers(table_name, trigger_name)

            if mysql?
              # Foreign key should be removed before removing column
              foreign_key = foreign_key_for(table_name, new)
              remove_foreign_key(table_name, column: new) if foreign_key
            end

            remove_column(table_name, new)
          end
        end
      end
    end

    def rename_column_safely_cleanup(table_name, old, new)
      if !postgresql? && !mysql?
        raise StrongMigrations::Error, "`#{__method__}` is intended for Postgres and Mysql only"
      end

      ensure_trigger_privileges(table_name)

      reversible do |dir|
        dir.up do
          trigger_name = rename_column_trigger_name(table_name, old, new)
          transaction do
            safety_assured do
              remove_column_rename_triggers(table_name, trigger_name)
              remove_column(table_name, old)
            end
          end
        end

        dir.down do
          copy_column(table_name, new, old)
          safety_assured { create_column_rename_triggers(table_name, old, new) }
        end
      end
    end

    def change_column_safely(table_name, column_name, type, options = {})
      ensure_postgresql(__method__)
      ensure_not_in_transaction(__method__)
      ensure_trigger_privileges(table_name)

      reversible do |dir|
        dir.up do
          temp_column = "#{column_name}_for_type_change"
          rename_column_safely(table_name, column_name, temp_column, type: type, **options)

          transaction do
            rename_column_safely_cleanup(table_name, column_name, temp_column)
            safety_assured { rename_column(table_name, temp_column, column_name) }
          end
        end

        dir.down do
          # same error message as Active Record
          raise ActiveRecord::IrreversibleMigration, <<~ERROR
            This migration uses #{__method__}, which is not automatically reversible.
            To make the migration reversible you can either:
            1. Define #up and #down methods in place of the #change method.
            2. Use the #reversible method to define reversible behavior.
          ERROR
        end
      end
    end

    private

    def ensure_postgresql(method_name)
      raise StrongMigrations::Error, "`#{method_name}` is intended for Postgres only" unless postgresql?
    end

    def ensure_not_in_transaction(method_name)
      if connection.transaction_open?
        raise StrongMigrations::Error, "Cannot run `#{method_name}` inside a transaction. Use `disable_ddl_transaction` to disable the transaction."
      end
    end

    # match https://github.com/nullobject/rein
    def null_constraint_name(table_name, column_name)
      "#{table_name}_#{column_name}_null"
    end

    def on_delete_update_statement(delete_or_update, action)
      on = delete_or_update.to_s.upcase

      case action
      when :nullify
        "ON #{on} SET NULL"
      when :cascade
        "ON #{on} CASCADE"
      when :restrict
        "ON #{on} RESTRICT"
      else
        # same error message as Active Record
        raise "'#{action}' is not supported for :on_update or :on_delete.\nSupported values are: :nullify, :cascade, :restrict"
      end
    end

    def ensure_trigger_privileges(table_name)
      privileges =
        if postgresql?
          trigger_privileges_postgresql?(table_name)
        else
          # It is very hard to check in Mysql if user has trigger privileges.
          # Let's assume that 'yes' and fail later.
          true
        end

      unless privileges
        raise StrongMigrations::Error, "Current database user cannot create, execute, or drop triggers on the #{table_name} table."
      end
    end

    def trigger_privileges_postgresql?(table_name)
      quoted_table = connection.quote(table_name)
      row = connection.exec_query("SELECT has_table_privilege(#{quoted_table}, 'TRIGGER')")
      row.first["has_table_privilege"]
    rescue ActiveRecord::StatementInvalid
      # Non-existing table
      false
    end

    def copy_column(table_name, old, new, options = {})
      old_column = columns(table_name).find { |c| c.name == old.to_s }
      type, limit, default, null, precision, scale, collation, comment = copy_column_options(old_column, options)

      add_column(table_name, new, type,
        limit: limit,
        precision: precision,
        scale: scale,
        comment: comment
      )

      change_column_default(table_name, new, default) if default.present?

      value_arel = Arel::Table.new(table_name)[old]
      backfill_column_safely(table_name, new, value_arel)

      add_null_constraint_safely(table_name, new) unless null

      copy_foreign_key(table_name, old, new)
      copy_indexes(table_name, old, new)
    end

    def copy_column_options(column, new_options)
      [:type, :limit, :default, :null, :precision, :scale, :collation, :comment].map do |option|
        new_options.fetch(option, column.send(option))
      end
    end

    def copy_foreign_key(table_name, old, new)
      fk = foreign_key_for(table_name, old)
      return unless fk

      options = {
        column: new,
        primary_key: fk.primary_key,
        on_delete: fk.on_delete,
        on_update: fk.on_update
      }

      if postgresql?
        add_foreign_key_safely(table_name, fk.to_table, options)
      else
        add_foreign_key(table_name, fk.to_table, options)
      end
    end

    def foreign_key_for(table_name, column_name)
      column_name = column_name.to_s
      connection.foreign_keys(table_name).find { |fk| fk.column == column_name }
    end

    def copy_indexes(table_name, old, new)
      old = old.to_s
      new = new.to_s

      indexes = connection.indexes(table_name).select { |index| index.columns.include?(old) }

      indexes.each do |index|
        new_columns = index.columns.map do |column|
          column == old ? new : column
        end

        options = copy_index_options(index, old, new)
        options[:algorithm] = :concurrently if postgresql?
        add_index(table_name, new_columns, options)
      end
    end

    def copy_index_options(index, old, new)
      unless index.name.include?(old)
        raise StrongMigrations::Error, <<~ERROR
            Cannot copy the index #{index.name} as it does not contain old column in its name.
            Rename it manually before proceeding.
          ERROR
      end

      name = index.name.gsub(old, new)

      options = {
        unique: index.unique,
        name: name,
        length: index.lengths,
        order: index.orders,
        where: index.where,
        using: index.using,
      }

      if ActiveRecord::VERSION::STRING >= "5.2"
        options[:opclass] = index.opclasses
      end

      options
    end

    def create_column_rename_triggers(table_name, old, new)
      trigger_name  = rename_column_trigger_name(table_name, old, new)
      quoted_table  = connection.quote_table_name(table_name)
      quoted_old    = connection.quote_column_name(old)
      quoted_new    = connection.quote_column_name(new)

      if postgresql?
        create_column_rename_triggers_postgresql(trigger_name, quoted_table, quoted_old, quoted_new)
      else
        create_column_rename_triggers_mysql(trigger_name, quoted_table, quoted_old, quoted_new)
      end
    end

    def rename_column_trigger_name(table_name, old, new)
      "trigger_rails_" + Digest::SHA256.hexdigest("#{table_name}_#{old}_#{new}").first(10)
    end

    def create_column_rename_triggers_postgresql(trigger, table, old, new)
      execute <<~SQL
        CREATE OR REPLACE FUNCTION #{trigger}() RETURNS trigger AS $$
          BEGIN
            NEW.#{new} := NEW.#{old};
            RETURN NEW;
          END;
        $$ LANGUAGE 'plpgsql';
      SQL

      execute <<~SQL
        DROP TRIGGER IF EXISTS #{trigger} ON #{table}
      SQL

      execute <<~SQL
        CREATE TRIGGER #{trigger} BEFORE INSERT OR UPDATE ON #{table}
          FOR EACH ROW EXECUTE PROCEDURE #{trigger}();
      SQL
    end

    def create_column_rename_triggers_mysql(trigger, table, old, new)
      insert_trigger = "#{trigger}_before_insert"
      update_trigger = "#{trigger}_before_update"

      execute <<~SQL
        DROP TRIGGER IF EXISTS #{insert_trigger}
      SQL

      execute <<~SQL
        CREATE TRIGGER #{insert_trigger} BEFORE INSERT ON #{table}
          FOR EACH ROW SET NEW.#{new} = NEW.#{old};
      SQL

      execute <<~SQL
        DROP TRIGGER IF EXISTS #{update_trigger}
      SQL

      execute <<~SQL
        CREATE TRIGGER #{update_trigger} BEFORE UPDATE ON #{table}
          FOR EACH ROW SET NEW.#{new} = NEW.#{old};
      SQL
    end

    def remove_column_rename_triggers(table, trigger)
      if postgresql?
        remove_column_rename_triggers_postgresql(table, trigger)
      else
        remove_column_rename_triggers_mysql(trigger)
      end
    end

    def remove_column_rename_triggers_postgresql(table, trigger)
      execute("DROP TRIGGER IF EXISTS #{trigger} ON #{table}")
      execute("DROP FUNCTION IF EXISTS #{trigger}()")
    end

    def remove_column_rename_triggers_mysql(trigger)
      insert_trigger = "#{trigger}_before_insert"
      update_trigger = "#{trigger}_before_update"

      execute("DROP TRIGGER IF EXISTS #{insert_trigger}")
      execute("DROP TRIGGER IF EXISTS #{update_trigger}")
    end
  end
end
