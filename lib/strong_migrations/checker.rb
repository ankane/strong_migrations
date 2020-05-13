module StrongMigrations
  class Checker
    attr_accessor :direction

    def initialize(migration)
      @migration = migration
      @new_tables = []
      @safe = false
      @timeouts_set = false
      @lock_timeout_checked = false
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
      check_lock_timeout

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

          if !default.nil? && !((postgresql? && postgresql_version >= Gem::Version.new("11")) || (mysql? && mysql_version >= Gem::Version.new("8.0.12")) || (mariadb? && mariadb_version >= Gem::Version.new("10.3.2")))

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
              append: append
          end

          if type.to_s == "json" && postgresql?
            raise_error :add_column_json
          end
        when :change_column
          table, column, type, options = args
          options ||= {}

          safe = false
          existing_column = connection.columns(table).find { |c| c.name.to_s == column.to_s }
          if existing_column
            sql_type = existing_column.sql_type.split("(").first
            if postgresql?
              case type.to_s
              when "string", "text"
                # safe to change limit for varchar
                safe = ["character varying", "text"].include?(sql_type)
              when "numeric", "decimal"
                # numeric and decimal are equivalent and can be used interchangably
                safe = ["numeric", "decimal"].include?(sql_type) &&
                  (
                    (
                      # unconstrained
                      !options[:precision] && !options[:scale]
                    ) || (
                      # increased precision, same scale
                      options[:precision] && existing_column.precision &&
                      options[:precision] >= existing_column.precision &&
                      options[:scale] == existing_column.scale
                    )
                  )
              when "datetime", "timestamp", "timestamptz"
                safe = ["timestamp without time zone", "timestamp with time zone"].include?(sql_type) &&
                  postgresql_version >= Gem::Version.new("12") &&
                  connection.select_all("SHOW timezone").first["TimeZone"] == "UTC"
              end
            elsif mysql? || mariadb?
              case type.to_s
              when "string"
                # https://dev.mysql.com/doc/refman/5.7/en/innodb-online-ddl-operations.html
                # https://mariadb.com/kb/en/innodb-online-ddl-operations-with-the-instant-alter-algorithm/#changing-the-data-type-of-a-column
                # increased limit, but doesn't change number of length bytes
                # 1-255 = 1 byte, 256-65532 = 2 bytes, 65533+ = too big for varchar
                limit = options[:limit] || 255
                safe = ["varchar"].include?(sql_type) &&
                  limit >= existing_column.limit &&
                  (limit <= 255 || existing_column.limit > 255)
              end
            end
          end
          raise_error :change_column unless safe
        when :create_table
          table, options = args
          options ||= {}

          raise_error :create_table if options[:force]

          # keep track of new tables of add_index check
          @new_tables << table.to_s
        when :add_reference, :add_belongs_to
          table, reference, options = args
          options ||= {}

          if postgresql?
            index_value = options.fetch(:index, true)
            concurrently_set = index_value.is_a?(Hash) && index_value[:algorithm] == :concurrently
            bad_index = index_value && !concurrently_set

            if bad_index || options[:foreign_key]
              columns = options[:polymorphic] ? [:"#{reference}_type", :"#{reference}_id"] : :"#{reference}_id"

              if index_value.is_a?(Hash)
                options[:index] = options[:index].merge(algorithm: :concurrently)
              else
                options = options.merge(index: {algorithm: :concurrently})
              end

              if options.delete(:foreign_key)
                headline = "Adding a validated foreign key locks the table."
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
        when :execute
          raise_error :execute, header: "Possibly dangerous operation"
        when :change_column_null
          table, column, null, default = args
          if !null
            if postgresql?
              # match https://github.com/nullobject/rein
              constraint_name = "#{table}_#{column}_null"

              raise_error :change_column_null_postgresql,
                add_constraint_code: constraint_str("ALTER TABLE %s ADD CONSTRAINT %s CHECK (%s IS NOT NULL) NOT VALID", [table, constraint_name, column]),
                validate_constraint_code: constraint_str("ALTER TABLE %s VALIDATE CONSTRAINT %s", [table, constraint_name])
            elsif mysql? || mariadb?
              raise_error :change_column_null_mysql
            elsif !default.nil?
              raise_error :change_column_null,
                code: backfill_code(table, column, default)
            end
          end
        when :add_foreign_key
          from_table, to_table, options = args
          options ||= {}

          # always validated before 5.2
          validate = options.fetch(:validate, true) || ActiveRecord::VERSION::STRING < "5.2"

          if postgresql? && validate
            if ActiveRecord::VERSION::STRING < "5.2"
              # fk name logic from rails
              primary_key = options[:primary_key] || "id"
              column = options[:column] || "#{to_table.to_s.singularize}_id"
              hashed_identifier = Digest::SHA256.hexdigest("#{from_table}_#{column}_fk").first(10)
              fk_name = options[:name] || "fk_rails_#{hashed_identifier}"

              raise_error :add_foreign_key,
                add_foreign_key_code: constraint_str("ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s) NOT VALID", [from_table, fk_name, column, to_table, primary_key]),
                validate_foreign_key_code: constraint_str("ALTER TABLE %s VALIDATE CONSTRAINT %s", [from_table, fk_name])
            else
              raise_error :add_foreign_key,
                add_foreign_key_code: command_str("add_foreign_key", [from_table, to_table, options.merge(validate: false)]),
                validate_foreign_key_code: command_str("validate_foreign_key", [from_table, to_table])
            end
          end
        end

        StrongMigrations.checks.each do |check|
          @migration.instance_exec(method, args, &check)
        end
      end

      result = yield

      # outdated statistics + a new index can hurt performance of existing queries
      if StrongMigrations.auto_analyze && direction == :up && method == :add_index
        if postgresql?
          # TODO remove verbose in 0.7.0
          connection.execute "ANALYZE VERBOSE #{connection.quote_table_name(args[0].to_s)}"
        elsif mariadb? || mysql?
          connection.execute "ANALYZE TABLE #{connection.quote_table_name(args[0].to_s)}"
        end
      end

      result
    end

    def set_timeouts
      if !@timeouts_set
        if StrongMigrations.statement_timeout
          statement =
            if postgresql?
              "SET statement_timeout TO #{connection.quote(postgresql_timeout(StrongMigrations.statement_timeout))}"
            elsif mysql?
              "SET max_execution_time = #{connection.quote(StrongMigrations.statement_timeout.to_i * 1000)}"
            elsif mariadb?
              "SET max_statement_time = #{connection.quote(StrongMigrations.statement_timeout)}"
            else
              raise StrongMigrations::Error, "Statement timeout not supported for this database"
            end

          connection.select_all(statement)
        end

        if StrongMigrations.lock_timeout
          statement =
            if postgresql?
              "SET lock_timeout TO #{connection.quote(postgresql_timeout(StrongMigrations.lock_timeout))}"
            elsif mysql? || mariadb?
              "SET lock_wait_timeout = #{connection.quote(StrongMigrations.lock_timeout)}"
            else
              raise StrongMigrations::Error, "Lock timeout not supported for this database"
            end

          connection.select_all(statement)
        end

        @timeouts_set = true
      end
    end

    private

    def connection
      @migration.connection
    end

    def version
      @migration.version
    end

    def safe?
      @safe || ENV["SAFETY_ASSURED"] || @migration.is_a?(ActiveRecord::Schema) || direction == :down || version_safe?
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def postgresql?
      connection.adapter_name =~ /postg/i # PostgreSQL, PostGIS
    end

    def postgresql_version
      @postgresql_version ||= begin
        target_version(StrongMigrations.target_postgresql_version) do
          # only works with major versions
          connection.select_all("SHOW server_version_num").first["server_version_num"].to_i / 10000
        end
      end
    end

    def mysql?
      connection.adapter_name =~ /mysql/i && !connection.try(:mariadb?)
    end

    def mysql_version
      @mysql_version ||= begin
        target_version(StrongMigrations.target_mysql_version) do
          connection.select_all("SELECT VERSION()").first["VERSION()"].split("-").first
        end
      end
    end

    def mariadb?
      connection.adapter_name =~ /mysql/i && connection.try(:mariadb?)
    end

    def mariadb_version
      @mariadb_version ||= begin
        target_version(StrongMigrations.target_mariadb_version) do
          connection.select_all("SELECT VERSION()").first["VERSION()"].split("-").first
        end
      end
    end

    def target_version(target_version)
      version =
        if target_version && StrongMigrations.developer_env?
          target_version.to_s
        else
          yield
        end
      Gem::Version.new(version)
    end

    def check_lock_timeout
      limit = StrongMigrations.lock_timeout_limit

      if limit && !@lock_timeout_checked
        if postgresql?
          lock_timeout = connection.select_all("SHOW lock_timeout").first["lock_timeout"]
          lock_timeout_sec = timeout_to_sec(lock_timeout)
          if lock_timeout_sec == 0
            warn "[strong_migrations] DANGER: No lock timeout set"
          elsif lock_timeout_sec > limit
            warn "[strong_migrations] DANGER: Lock timeout is longer than #{limit} seconds: #{lock_timeout}"
          end
        elsif mysql? || mariadb?
          lock_timeout = connection.select_all("SHOW VARIABLES LIKE 'lock_wait_timeout'").first["Value"]
          if lock_timeout.to_i > limit
            warn "[strong_migrations] DANGER: Lock timeout is longer than #{limit} seconds: #{lock_timeout}"
          end
        end
        @lock_timeout_checked = true
      end
    end

    # units: https://www.postgresql.org/docs/current/config-setting.html
    def timeout_to_sec(timeout)
      units = {
        "us" => 0.001,
        "ms" => 1,
        "s" => 1000,
        "min" => 1000 * 60,
        "h" => 1000 * 60 * 60,
        "d" => 1000 * 60 * 60 * 24
      }
      timeout_ms = timeout.to_i
      units.each do |k, v|
        if timeout.end_with?(k)
          timeout_ms *= v
          break
        end
      end
      timeout_ms / 1000.0
    end

    def postgresql_timeout(timeout)
      if timeout.is_a?(String)
        timeout
      else
        timeout.to_i * 1000
      end
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
      code = statement % identifiers.map { |v| connection.quote_table_name(v) }
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
