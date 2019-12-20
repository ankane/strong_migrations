module StrongMigrations
  module MigrationHelpers
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

    private

    def ensure_postgresql(method_name)
      raise StrongMigrations::Error, "`#{method_name}` is intended for Postgres only" unless postgresql?
    end

    def postgresql?
      %w(PostgreSQL PostGIS).include?(connection.adapter_name)
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

    def quote_identifiers(statement, identifiers)
      statement % identifiers.map { |v| connection.quote_table_name(v) }
    end
  end
end
