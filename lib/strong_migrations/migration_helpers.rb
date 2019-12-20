module StrongMigrations
  module MigrationHelpers

    # Adds a new foreign key with minimal impact on concurrent updates.
    #
    # Example:
    #
    #     add_foreign_key_concurrently :articles, :authors
    #
    # Refer to Rails' `add_foreign_key` for more info on available options.
    def add_foreign_key_concurrently(from_table, to_table, options = {})
      ensure_postgresql(__method__)
      ensure_not_in_transaction(__method__)

      if ActiveRecord::VERSION::STRING >= "5.2"
        add_foreign_key(from_table, to_table, options.merge(validate: false))
        validate_foreign_key(from_table, to_table)
      else
        options = foreign_key_options(from_table, to_table, options)

        safety_assured do
          fk_name, column, primary_key = options.values_at(:name, :column, :primary_key)
          primary_key ||= "id"

          reversible do |dir|
            dir.up do
              execute quote_identifiers(<<~SQL, [from_table, fk_name, column, to_table, primary_key])
                ALTER TABLE %s
                ADD CONSTRAINT %s
                FOREIGN KEY (%s)
                REFERENCES %s (%s)
                #{on_delete_update_statement(:delete, options[:on_delete])}
                #{on_delete_update_statement(:update, options[:on_update])}
                NOT VALID;
              SQL

              execute quote_identifiers("ALTER TABLE %s VALIDATE CONSTRAINT %s;", [from_table, fk_name])
            end

            dir.down do
              remove_foreign_key(from_table, to_table)
            end
          end
        end
      end
    end

    private

    def ensure_postgresql(method_name)
      raise "`#{method_name}` is intended for Postgres usage only" unless postgresql?
    end

    def postgresql?
      %w(PostgreSQL PostGIS).include?(connection.adapter_name)
    end

    def ensure_not_in_transaction(method_name)
      if transaction_open?
        raise <<~EOF
          Cannot run `#{method_name}` inside a transaction.
          To disable the transaction wrapping this migration, you can use `disable_ddl_transaction!`.
        EOF
      end
    end

    def on_delete_update_statement(delete_or_update, action)
      delete_or_update = delete_or_update.to_s

      case action
      when nil, ""
        ""
      when :nullify
        "ON #{delete_or_update.upcase} SET NULL"
      else
        "ON #{delete_or_update.upcase} #{action.upcase}"
      end
    end

    def quote_identifiers(statement, identifiers)
      statement % identifiers.map { |v| connection.quote_table_name(v) }
    end
  end
end
