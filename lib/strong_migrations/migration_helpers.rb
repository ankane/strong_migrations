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
      count_arel = table.project(Arel.star.count)
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
  end
end
