module StrongMigrations
  class Checker
    include Util

    attr_accessor :direction

    def initialize(migration)
      @migration = migration
      @new_tables = []
      @safe = false
      @timeouts_set = false
    end

    def safety_assured
      previous_value = @safe
      begin
        @safe = true
        yield
      ensure
        @safe = previous_value
      end
    end

    def perform(method, *args)
      set_timeouts

      unless safe?
        case method
        when :remove_column, :remove_columns, :remove_timestamps, :remove_reference, :remove_belongs_to
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
        when :change_table
          raise_error :change_table, header: "Possibly dangerous operation"
        when :rename_table
          raise_error :rename_table
        when :rename_column
          raise_error :rename_column
        when :add_index
          table, columns, options = args
          options ||= {}

          if columns.is_a?(Array) && columns.size > 3 && !options[:unique]
            raise_error :add_index_columns, header: "Best practice"
          end
          if postgresql? && options[:algorithm] != :concurrently && !new_table?(table)
            raise_error :add_index, command: command_str("add_index", [table, columns, options.merge(algorithm: :concurrently)])
          end
        when :remove_index
          table, options = args
          unless options.is_a?(Hash)
            options = {column: options}
          end
          options ||= {}

          if postgresql? && options[:algorithm] != :concurrently && !new_table?(table)
            raise_error :remove_index, command: command_str("remove_index", [table, options.merge(algorithm: :concurrently)])
          end
        when :add_column
          table, column, type, options = args
          options ||= {}
          default = options[:default]

          if !default.nil? && !(postgresql? && postgresql_version >= 110000)
            raise_error :add_column_default,
              command: command_str("add_column_safely", [table, column, type, options])
          end

          if type.to_s == "json" && postgresql?
            raise_error :add_column_json
          end
        when :change_column
          table, column, type, options = args
          options ||= {}

          safe = false
          found_column = connection.columns(table).find { |c| c.name.to_s == column.to_s }
          raise StrongMigrations::Error, "Column '#{column}' of relation '#{table}' does not exist" unless found_column

          # assume Postgres 9.1+ since previous versions are EOL
          if postgresql? && type.to_s == "text"
            safe = found_column.type == :string
          end

          unless safe
            down_options = {}
            options.each do |option, value|
              if value != found_column.send(option)
                down_options[option] = found_column.send(option)
              end
            end
            previous_type = found_column.type

            raise_error :change_column,
              up_command: command_str("change_column_safely", [table, column, type, options]),
              down_command: command_str("change_column_safely", [table, column, previous_type, down_options])
          end
        when :create_table
          table, options = args
          options ||= {}

          raise_error :create_table if options[:force]

          # keep track of new tables of add_index check
          @new_tables << table.to_s
        when :add_reference, :add_belongs_to
          table, reference, options = args
          options ||= {}

          index_value = options.fetch(:index, true)
          concurrently_set = index_value.is_a?(Hash) && index_value[:algorithm] == :concurrently

          if postgresql? && index_value && !concurrently_set
            columns = options[:polymorphic] ? [:"#{reference}_type", :"#{reference}_id"] : :"#{reference}_id"

            if index_value.is_a?(Hash)
              options[:index] = options[:index].merge(algorithm: :concurrently)
            else
              options = options.merge(index: {algorithm: :concurrently})
            end

            raise_error :add_reference, command: command_str(method, [table, reference, options])
          end
        when :execute
          raise_error :execute, header: "Possibly dangerous operation"
        when :change_column_null
          table, column, null, default = args
          if !null
            if postgresql?
              raise_error :change_column_null_postgresql,
                command: command_str(:add_null_constraint_safely, [table, column])
            elsif !default.nil?
              raise_error :change_column_null,
                code: backfill_code(table, column, default)
            end
          end
        when :add_foreign_key
          from_table, to_table, options = args
          options ||= {}
          validate = options.fetch(:validate, true)

          if postgresql?
            if ActiveRecord::VERSION::STRING < "5.2" || validate
              raise_error :add_foreign_key,
                command: command_str(:add_foreign_key_safely, [from_table, to_table, options])
            end
          end
        end

        StrongMigrations.checks.each do |check|
          @migration.instance_exec(method, args, &check)
        end
      end

      result = yield

      if StrongMigrations.auto_analyze && direction == :up && postgresql? && method == :add_index
        connection.execute "ANALYZE VERBOSE #{connection.quote_table_name(args[0].to_s)}"
      end

      result
    end

    def set_timeouts
      if !@timeouts_set
        connection.select_all("SET statement_timeout TO #{connection.quote(StrongMigrations.statement_timeout)}") if StrongMigrations.statement_timeout
        connection.select_all("SET lock_timeout TO #{connection.quote(StrongMigrations.lock_timeout)}") if StrongMigrations.lock_timeout
        @timeouts_set = true
      end
    end

    private

    def version
      @migration.version
    end

    def safe?
      @safe || ENV["SAFETY_ASSURED"] || @migration.is_a?(ActiveRecord::Schema) || direction == :down || version_safe?
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def raise_error(message_key, header: nil, **vars)
      return unless StrongMigrations.check_enabled?(message_key, version: version)

      message = StrongMigrations.error_messages[message_key] || "Missing message"

      vars[:migration_name] = @migration.class.name
      vars[:migration_suffix] = "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      vars[:base_model] = "ApplicationRecord"

      # interpolate variables in appended code
      if vars[:append]
        vars[:append] = vars[:append].gsub(/%(?!{)/, "%%") % vars
      end

      # escape % not followed by {
      @migration.stop!(message.gsub(/%(?!{)/, "%%") % vars, header: header || "Dangerous operation detected")
    end

    def constraint_str(statement, identifiers)
      # not all identifiers are tables, but this method of quoting should be fine
      code = quote_identifiers(statement, identifiers)
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
      "#{model}.unscoped.in_batches do |relation| \n      relation.update_all #{column}: #{default.inspect}\n      sleep(0.1)\n    end"
    end

    def new_table?(table)
      @new_tables.include?(table.to_s)
    end
  end
end
