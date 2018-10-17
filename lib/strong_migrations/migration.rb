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
        ar5 = ActiveRecord::VERSION::MAJOR >= 5
        model = model_str(args[0])

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

          code = ar5 ? "self.ignored_columns = #{columns.inspect}" : "def self.columns\n    super.reject { |c| #{columns.inspect}.include?(c.name) }\n  end"

          raise_error :remove_column,
            model: model,
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
          if postgresql? && options[:algorithm] != :concurrently && !@new_tables.to_a.include?(table.to_s)
            raise_error :add_index, command: command_str("add_index", [table, columns, options.merge(algorithm: :concurrently)])
          end
        when :add_column
          table, column, type, options = args
          options ||= {}
          default = options[:default]

          if !default.nil? && !(postgresql? && postgresql_version >= 110000)
            raise_error :add_column_default,
              add_command: command_str("add_column", [table, column, type, options.except(:default)]),
              change_command: command_str("change_column_default", [table, column, default]),
              remove_command: command_str("remove_column", [table, column]),
              code: backfill_code(table, column, default)
          end

          if type.to_s == "json" && postgresql?
            if postgresql_version >= 90400
              raise_error :add_column_json
            else
              raise_error :add_column_json_legacy,
                model: model,
                table: connection.quote_table_name(table.to_s)
            end
          end
        when :change_column
          table, column, type = args

          safe = false
          # assume Postgres 9.1+ since previous versions are EOL
          if postgresql? && type.to_s == "text"
            found_column = connection.columns(table).find { |c| c.name.to_s == column.to_s }
            safe = found_column && found_column.type == :string
          end
          raise_error :change_column unless safe
        when :create_table
          table, options = args
          options ||= {}
          raise_error :create_table if options[:force]
          (@new_tables ||= []) << table.to_s
        when :add_reference, :add_belongs_to
          table, reference, options = args
          options ||= {}

          index_value = options.fetch(:index, ar5)
          if postgresql? && index_value
            columns = options[:polymorphic] ? [:"#{reference}_type", :"#{reference}_id"] : :"#{reference}_id"

            raise_error :add_reference,
              add_command: command_str(method, [table, reference, options.merge(index: false)]),
              index_command: command_str("add_index", [table, columns])
          end
        when :execute
          raise_error :execute, header: "Possibly dangerous operation"
        when :change_column_null
          table, column, null, default = args
          if !null && !default.nil?
            raise_error :change_column_null,
              code: backfill_code(table, column, default)
          end
        end

        StrongMigrations.checks.each do |check|
          instance_exec(method, args, &check)
        end
      end

      result = super

      if StrongMigrations.auto_analyze && @direction == :up && postgresql? && method == :add_index
        connection.execute "ANALYZE VERBOSE #{connection.quote_table_name(args[0].to_s)}"
      end

      result
    end

    private

    def postgresql?
      %w(PostgreSQL PostGIS).include?(connection.adapter_name)
    end

    def postgresql_version
      @postgresql_version ||= connection.execute("SHOW server_version_num").first["server_version_num"].to_i
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def raise_error(message_key, header: nil, **vars)
      message = StrongMigrations.error_messages[message_key] || "Missing message"

      ar5 = ActiveRecord::VERSION::MAJOR >= 5
      vars[:migration_name] = self.class.name
      vars[:migration_suffix] = ar5 ? "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]" : ""
      vars[:base_model] = ar5 ? "ApplicationRecord" : "ActiveRecord::Base"

      # escape % not followed by {
      stop!(message.gsub(/%(?!{)/, "%%") % vars, header: header || "Dangerous operation detected")
    end

    def model_str(v)
      v.to_s.classify
    end

    def command_str(command, args)
      str_args = args[0..-2].map { |a| a.inspect }

      # prettier last arg
      last_arg = args[-1]
      if last_arg.is_a?(Hash)
        if last_arg.any?
          str_args << last_arg.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        end
      else
        str_args << last_arg.inspect
      end

      "#{command} #{str_args.join(", ")}"
    end

    def backfill_code(table, column, default)
      model = model_str(table)
      if ActiveRecord::VERSION::MAJOR >= 5
        "#{model}.in_batches.update_all #{column}: #{default.inspect}"
      else
        "#{model}.find_in_batches do |records|\n      #{model}.where(id: records.map(&:id)).update_all #{column}: #{default.inspect}\n    end"
      end
    end

    def stop!(message, header: "Custom check")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}\n"
    end
  end
end
