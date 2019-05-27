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
          if postgresql? && options[:algorithm] != :concurrently && !@new_tables.to_a.include?(table.to_s)
            raise_error :add_index, command: command_str("add_index", [table, columns, options.merge(algorithm: :concurrently)])
          end
        when :add_column
          table, column, type, options = args
          options ||= {}
          default = options[:default]

          if !default.nil? && !(postgresql? && postgresql_version >= 110000)

            if options[:null] == false
              options = options.except(:null)
              append = "

Then add the NOT NULL constraint.

class %{migration_name}NotNull < ActiveRecord::Migration%{migration_suffix}
  def change
    #{command_str("change_column_null", [table, column, false])}
  end
end"
            end

            raise_error :add_column_default,
              add_command: command_str("add_column", [table, column, type, options.except(:default)]),
              change_command: command_str("change_column_default", [table, column, default]),
              remove_command: command_str("remove_column", [table, column]),
              code: backfill_code(table, column, default),
              append: append
          end

          if type.to_s == "json" && postgresql?
            raise_error :add_column_json
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

          # keep track of new tables of add_index check
          (@new_tables ||= []) << table.to_s
        when :add_reference, :add_belongs_to
          table, reference, options = args
          options ||= {}

          index_value = options.fetch(:index, true)
          if postgresql? && index_value
            columns = options[:polymorphic] ? [:"#{reference}_type", :"#{reference}_id"] : :"#{reference}_id"

            raise_error :add_reference,
              reference_command: command_str(method, [table, reference, options.merge(index: false)]),
              index_command: command_str("add_index", [table, columns, {algorithm: :concurrently}])
          end
        when :execute
          raise_error :execute, header: "Possibly dangerous operation"
        when :change_column_null
          table, column, null, default = args
          if !null && !default.nil?
            raise_error :change_column_null,
              code: backfill_code(table, column, default)
          end
        when :add_foreign_key
          from_table, to_table, options = args
          options ||= {}
          validate = options.fetch(:validate, true)

          if postgresql?
            if ActiveRecord::VERSION::STRING >= "5.2"
              if validate
                raise_error :add_foreign_key,
                  add_foreign_key_code: command_str("add_foreign_key", [from_table, to_table, options.merge(validate: false)]),
                  validate_foreign_key_code: command_str("validate_foreign_key", [from_table, to_table])
              end
            else
              # always validated before 5.2

              # fk name logic from rails
              primary_key = options[:primary_key] || "id"
              column = options[:column] || "#{to_table.to_s.singularize}_id"
              hashed_identifier = Digest::SHA256.hexdigest("#{from_table}_#{column}_fk").first(10)
              fk_name = options[:name] || "fk_rails_#{hashed_identifier}"

              raise_error :add_foreign_key,
                add_foreign_key_code: foreign_key_str("ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s) NOT VALID", [from_table, fk_name, column, to_table, primary_key]),
                validate_foreign_key_code: foreign_key_str("ALTER TABLE %s VALIDATE CONSTRAINT %s", [from_table, fk_name])
            end
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

      vars[:migration_name] = self.class.name
      vars[:migration_suffix] = "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      vars[:base_model] = "ApplicationRecord"

      # interpolate variables in appended code
      if vars[:append]
        vars[:append] = vars[:append].gsub(/%(?!{)/, "%%") % vars
      end

      # escape % not followed by {
      stop!(message.gsub(/%(?!{)/, "%%") % vars, header: header || "Dangerous operation detected")
    end

    def foreign_key_str(statement, identifiers)
      # not all identifiers are tables, but this method of quoting should be fine
      code = statement % identifiers.map { |v| connection.quote_table_name(v) }
      "safety_assured do\n      execute '#{code}' \n    end"
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
      model = table.to_s.classify
      "#{model}.in_batches do |relation| \n      relation.update_all #{column}: #{default.inspect}\n      sleep(0.1)\n    end"
    end

    def stop!(message, header: "Custom check")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}\n"
    end
  end
end
