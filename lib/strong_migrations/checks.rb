# TODO better pattern
module StrongMigrations
  module Checks
    private

    def check_add_check_constraint(args)
      table, expression, options = args
      options ||= {}

      if !new_table?(table)
        if postgresql? && options[:validate] != false
          add_options = options.merge(validate: false)
          name = options[:name] || @migration.check_constraint_options(table, expression, options)[:name]
          validate_options = {name: name}

          if StrongMigrations.safe_by_default
            safe_add_check_constraint(table, expression, add_options, validate_options)
            throw :safe
          end

          raise_error :add_check_constraint,
            add_check_constraint_code: command_str("add_check_constraint", [table, expression, add_options]),
            validate_check_constraint_code: command_str("validate_check_constraint", [table, validate_options])
        elsif mysql? || mariadb?
          raise_error :add_check_constraint_mysql
        end
      end
    end

    def check_add_column(args)
      table, column, type, options = args
      options ||= {}
      default = options[:default]

      if !default.nil? && !adapter.add_column_default_safe?
        if options[:null] == false
          options = options.except(:null)
          append = "

Then add the NOT NULL constraint in separate migrations."
        end

        raise_error :add_column_default,
          add_command: command_str("add_column", [table, column, type, options.except(:default)]),
          change_command: command_str("change_column_default", [table, column, default]),
          remove_command: command_str("remove_column", [table, column]),
          code: backfill_code(table, column, default),
          append: append,
          rewrite_blocks: adapter.rewrite_blocks
      elsif default.is_a?(Proc) && postgresql?
        # adding a column with a VOLATILE default is not safe
        # https://www.postgresql.org/docs/current/sql-altertable.html#SQL-ALTERTABLE-NOTES
        # functions like random() and clock_timestamp() are VOLATILE
        # check for Proc to match Active Record
        raise_error :add_column_default_callable
      end

      if type.to_s == "json" && postgresql?
        raise_error :add_column_json,
          command: command_str("add_column", [table, column, :jsonb, options])
      end
    end

    # unlike add_index, we don't make an exception here for new tables
    #
    # with add_index, it's fine to lock a new table even after inserting data
    # since the table won't be in use by the application
    #
    # with add_foreign_key, this would cause issues since it locks the referenced table
    #
    # it's okay to allow if the table is empty, but not a fan of data-dependent checks,
    # since the data in production could be different from development
    #
    # note: adding foreign_keys with create_table is fine
    # since the table is always guaranteed to be empty
    def check_add_foreign_key(args)
      from_table, to_table, options = args
      options ||= {}

      validate = options.fetch(:validate, true)
      if postgresql? && validate
        if StrongMigrations.safe_by_default
          safe_add_foreign_key(from_table, to_table, options)
          throw :safe
        end

        raise_error :add_foreign_key,
          add_foreign_key_code: command_str("add_foreign_key", [from_table, to_table, options.merge(validate: false)]),
          validate_foreign_key_code: "def change\n    #{command_str("validate_foreign_key", [from_table, to_table])}\n  end"
      end
    end

    def check_add_index(args)
      table, columns, options = args
      options ||= {}

      if columns.is_a?(Array) && columns.size > 3 && !options[:unique]
        raise_error :add_index_columns, header: "Best practice"
      end

      # safe to add non-concurrently to new tables (even after inserting data)
      # since the table won't be in use by the application
      if postgresql? && options[:algorithm] != :concurrently && !new_table?(table)
        if StrongMigrations.safe_by_default
          safe_add_index(table, columns, options)
          throw :safe
        end

        raise_error :add_index, command: command_str("add_index", [table, columns, options.merge(algorithm: :concurrently)])
      end
    end

    def check_add_reference(method, args)
      table, reference, options = args
      options ||= {}

      if postgresql?
        index_value = options.fetch(:index, true)
        concurrently_set = index_value.is_a?(Hash) && index_value[:algorithm] == :concurrently
        bad_index = index_value && !concurrently_set

        if bad_index || options[:foreign_key]
          if index_value.is_a?(Hash)
            options[:index] = options[:index].merge(algorithm: :concurrently)
          else
            options = options.merge(index: {algorithm: :concurrently})
          end

          if StrongMigrations.safe_by_default
            safe_add_reference(table, reference, options)
            throw :safe
          end

          if options.delete(:foreign_key)
            headline = "Adding a foreign key blocks writes on both tables."
            append = "

Then add the foreign key in separate migrations."
          else
            headline = "Adding an index non-concurrently locks the table."
          end

          raise_error :add_reference,
            headline: headline,
            command: command_str(method, [table, reference, options]),
            append: append
        end
      end
    end

    def check_change_column(args)
      table, column, type, options = args
      options ||= {}

      safe = false
      existing_column = connection.columns(table).find { |c| c.name.to_s == column.to_s }
      if existing_column
        existing_type = existing_column.sql_type.sub(/\(\d+(,\d+)?\)/, "")
        safe = adapter.change_type_safe?(table, column, type, options, existing_column, existing_type)
      end

      # unsafe to set NOT NULL for safe types with Postgres
      # TODO check if safe for MySQL and MariaDB
      if safe && existing_column.null && options[:null] == false
        raise_error :change_column_with_not_null
      end

      raise_error :change_column, rewrite_blocks: adapter.rewrite_blocks unless safe
    end

    def check_change_column_null(args)
      table, column, null, default = args
      if !null
        if postgresql?
          safe = false
          safe_with_check_constraint = adapter.server_version >= Gem::Version.new("12")
          if safe_with_check_constraint
            safe = adapter.constraints(table).any? { |c| c["def"] == "CHECK ((#{column} IS NOT NULL))" || c["def"] == "CHECK ((#{connection.quote_column_name(column)} IS NOT NULL))" }
          end

          unless safe
            # match https://github.com/nullobject/rein
            constraint_name = "#{table}_#{column}_null"

            add_code = constraint_str("ALTER TABLE %s ADD CONSTRAINT %s CHECK (%s IS NOT NULL) NOT VALID", [table, constraint_name, column])
            validate_code = constraint_str("ALTER TABLE %s VALIDATE CONSTRAINT %s", [table, constraint_name])
            remove_code = constraint_str("ALTER TABLE %s DROP CONSTRAINT %s", [table, constraint_name])

            constraint_methods = ar_version >= 6.1

            validate_constraint_code =
              if constraint_methods
                String.new(command_str(:validate_check_constraint, [table, {name: constraint_name}]))
              else
                String.new(safety_assured_str(validate_code))
              end

            if safe_with_check_constraint
              change_args = [table, column, null]

              validate_constraint_code << "\n    #{command_str(:change_column_null, change_args)}"

              if constraint_methods
                validate_constraint_code << "\n    #{command_str(:remove_check_constraint, [table, {name: constraint_name}])}"
              else
                validate_constraint_code << "\n    #{safety_assured_str(remove_code)}"
              end
            end

            if StrongMigrations.safe_by_default
              safe_change_column_null(add_code, validate_code, change_args, remove_code, default)
              throw :safe
            end

            add_constraint_code =
              if constraint_methods
                # only quote when needed
                expr_column = column.to_s =~ /\A[a-z0-9_]+\z/ ? column : connection.quote_column_name(column)
                command_str(:add_check_constraint, [table, "#{expr_column} IS NOT NULL", {name: constraint_name, validate: false}])
              else
                safety_assured_str(add_code)
              end

            raise_error :change_column_null_postgresql,
              add_constraint_code: add_constraint_code,
              validate_constraint_code: validate_constraint_code
          end
        elsif mysql? || mariadb?
          unless adapter.strict_mode?
            raise_error :change_column_null_mysql
          end
        end

        if !default.nil?
          raise_error :change_column_null,
            code: backfill_code(table, column, default)
        end
      end
    end

    def check_change_table
      raise_error :change_table, header: "Possibly dangerous operation"
    end

    def check_create_table(args)
      table, options = args
      options ||= {}

      raise_error :create_table if options[:force]

      # keep track of new tables of add_index check
      @new_tables << table.to_s
    end

    def check_execute
      raise_error :execute, header: "Possibly dangerous operation"
    end

    def check_remove_column(method, args)
      columns =
        case method
        when :remove_timestamps
          ["created_at", "updated_at"]
        when :remove_column
          [args[1].to_s]
        when :remove_columns
          args[1..-1].map(&:to_s)
        else
          options = args[2] || {}
          reference = args[1]
          cols = []
          cols << "#{reference}_type" if options[:polymorphic]
          cols << "#{reference}_id"
          cols
        end

      code = "self.ignored_columns = #{columns.inspect}"

      raise_error :remove_column,
        model: args[0].to_s.classify,
        code: code,
        command: command_str(method, args),
        column_suffix: columns.size > 1 ? "s" : ""
    end

    def check_remove_index(args)
      table, options = args
      unless options.is_a?(Hash)
        options = {column: options}
      end
      options ||= {}

      if postgresql? && options[:algorithm] != :concurrently && !new_table?(table)
        if StrongMigrations.safe_by_default
          safe_remove_index(table, options)
          throw :safe
        end

        raise_error :remove_index, command: command_str("remove_index", [table, options.merge(algorithm: :concurrently)])
      end
    end

    def check_rename_column
      raise_error :rename_column
    end

    def check_rename_table
      raise_error :rename_table
    end

    def check_validate_check_constraint
      if postgresql? && adapter.writes_blocked?
        raise_error :validate_check_constraint
      end
    end

    def check_validate_foreign_key
      if postgresql? && adapter.writes_blocked?
        raise_error :validate_foreign_key
      end
    end

    # helpers

    def postgresql?
      adapter.instance_of?(Adapters::PostgreSQLAdapter)
    end

    def mysql?
      adapter.instance_of?(Adapters::MySQLAdapter)
    end

    def mariadb?
      adapter.instance_of?(Adapters::MariaDBAdapter)
    end

    def ar_version
      ActiveRecord::VERSION::STRING.to_f
    end

    def raise_error(message_key, header: nil, append: nil, **vars)
      return unless StrongMigrations.check_enabled?(message_key, version: version)

      message = StrongMigrations.error_messages[message_key] || "Missing message"
      message = message + append if append

      vars[:migration_name] = @migration.class.name
      vars[:migration_suffix] = "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      vars[:base_model] = "ApplicationRecord"

      # escape % not followed by {
      message = message.gsub(/%(?!{)/, "%%") % vars if message.include?("%")
      @migration.stop!(message, header: header || "Dangerous operation detected")
    end

    def constraint_str(statement, identifiers)
      # not all identifiers are tables, but this method of quoting should be fine
      statement % identifiers.map { |v| connection.quote_table_name(v) }
    end

    def safety_assured_str(code)
      "safety_assured do\n      execute '#{code}' \n    end"
    end

    def command_str(command, args)
      str_args = args[0..-2].map { |a| a.inspect }

      # prettier last arg
      last_arg = args[-1]
      if last_arg.is_a?(Hash)
        if last_arg.any?
          str_args << last_arg.map do |k, v|
            if v.is_a?(Hash)
              # pretty index: {algorithm: :concurrently}
              "#{k}: {#{v.map { |k2, v2| "#{k2}: #{v2.inspect}" }.join(", ")}}"
            else
              "#{k}: #{v.inspect}"
            end
          end.join(", ")
        end
      else
        str_args << last_arg.inspect
      end

      "#{command} #{str_args.join(", ")}"
    end

    def backfill_code(table, column, default)
      model = table.to_s.classify
      "#{model}.unscoped.in_batches do |relation| \n      relation.update_all #{column}: #{default.inspect}\n      sleep(0.01)\n    end"
    end

    def new_table?(table)
      @new_tables.include?(table.to_s)
    end
  end
end
