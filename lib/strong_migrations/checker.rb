module StrongMigrations
  class Checker
    include SafeMethods

    attr_accessor :direction, :transaction_disabled

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

      if !safe? || safe_by_default_method?(method)
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
            return safe_add_index(table, columns, options) if StrongMigrations.safe_by_default
            raise_error :add_index, command: command_str("add_index", [table, columns, options.merge(algorithm: :concurrently)])
          end
        when :remove_index
          table, options = args
          unless options.is_a?(Hash)
            options = {column: options}
          end
          options ||= {}

          if postgresql? && options[:algorithm] != :concurrently && !new_table?(table)
            return safe_remove_index(table, options) if StrongMigrations.safe_by_default
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
              append: append,
              rewrite_blocks: rewrite_blocks
          end

          if type.to_s == "json" && postgresql?
            raise_error :add_column_json,
              command: command_str("add_column", [table, column, :jsonb, options])
          end
        when :change_column
          table, column, type, options = args
          options ||= {}

          safe = false
          existing_column = connection.columns(table).find { |c| c.name.to_s == column.to_s }
          if existing_column
            existing_type = existing_column.sql_type.split("(").first
            if postgresql?
              case type.to_s
              when "string"
                # safe to increase limit or remove it
                # not safe to decrease limit or add a limit
                case existing_type
                when "character varying"
                  safe = !options[:limit] || (existing_column.limit && options[:limit] >= existing_column.limit)
                when "text"
                  safe = !options[:limit]
                end
              when "text"
                # safe to change varchar to text (and text to text)
                safe = ["character varying", "text"].include?(existing_type)
              when "numeric", "decimal"
                # numeric and decimal are equivalent and can be used interchangably
                safe = ["numeric", "decimal"].include?(existing_type) &&
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
                safe = ["timestamp without time zone", "timestamp with time zone"].include?(existing_type) &&
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
                safe = ["varchar"].include?(existing_type) &&
                  limit >= existing_column.limit &&
                  (limit <= 255 || existing_column.limit > 255)
              end
            end
          end

          # unsafe to set NOT NULL for safe types
          if safe && existing_column.null && options[:null] == false
            raise_error :change_column_with_not_null
          end

          raise_error :change_column, rewrite_blocks: rewrite_blocks unless safe
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
              if index_value.is_a?(Hash)
                options[:index] = options[:index].merge(algorithm: :concurrently)
              else
                options = options.merge(index: {algorithm: :concurrently})
              end

              return safe_add_reference(table, reference, options) if StrongMigrations.safe_by_default

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
        when :execute
          raise_error :execute, header: "Possibly dangerous operation"
        when :change_column_null
          table, column, null, default = args
          if !null
            if postgresql?
              safe = false
              if postgresql_version >= Gem::Version.new("12")
                safe = constraints(table).any? { |c| c["def"] == "CHECK ((#{column} IS NOT NULL))" || c["def"] == "CHECK ((#{connection.quote_column_name(column)} IS NOT NULL))" }
              end

              unless safe
                # match https://github.com/nullobject/rein
                constraint_name = "#{table}_#{column}_null"

                add_code = constraint_str("ALTER TABLE %s ADD CONSTRAINT %s CHECK (%s IS NOT NULL) NOT VALID", [table, constraint_name, column])
                validate_code = constraint_str("ALTER TABLE %s VALIDATE CONSTRAINT %s", [table, constraint_name])
                remove_code = constraint_str("ALTER TABLE %s DROP CONSTRAINT %s", [table, constraint_name])

                validate_constraint_code =
                  if ar_version >= 6.1
                    String.new(command_str(:validate_check_constraint, [table, {name: constraint_name}]))
                  else
                    String.new(safety_assured_str(validate_code))
                  end

                if postgresql_version >= Gem::Version.new("12")
                  change_args = [table, column, null]

                  validate_constraint_code << "\n    #{command_str(:change_column_null, change_args)}"

                  if ar_version >= 6.1
                    validate_constraint_code << "\n    #{command_str(:remove_check_constraint, [table, {name: constraint_name}])}"
                  else
                    validate_constraint_code << "\n    #{safety_assured_str(remove_code)}"
                  end
                end

                return safe_change_column_null(add_code, validate_code, change_args, remove_code) if StrongMigrations.safe_by_default

                add_constraint_code =
                  if ar_version >= 6.1
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
          validate = options.fetch(:validate, true) || ar_version < 5.2

          if postgresql? && validate
            if ar_version < 5.2
              # fk name logic from rails
              primary_key = options[:primary_key] || "id"
              column = options[:column] || "#{to_table.to_s.singularize}_id"
              hashed_identifier = Digest::SHA256.hexdigest("#{from_table}_#{column}_fk").first(10)
              fk_name = options[:name] || "fk_rails_#{hashed_identifier}"

              add_code = constraint_str("ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s) NOT VALID", [from_table, fk_name, column, to_table, primary_key])
              validate_code = constraint_str("ALTER TABLE %s VALIDATE CONSTRAINT %s", [from_table, fk_name])

              return safe_add_foreign_key_code(from_table, to_table, add_code, validate_code) if StrongMigrations.safe_by_default

              raise_error :add_foreign_key,
                add_foreign_key_code: safety_assured_str(add_code),
                validate_foreign_key_code: safety_assured_str(validate_code)
            else
              return safe_add_foreign_key(from_table, to_table, options) if StrongMigrations.safe_by_default

              raise_error :add_foreign_key,
                add_foreign_key_code: command_str("add_foreign_key", [from_table, to_table, options.merge(validate: false)]),
                validate_foreign_key_code: command_str("validate_foreign_key", [from_table, to_table])
            end
          end
        when :validate_foreign_key
          if postgresql? && writes_blocked?
            raise_error :validate_foreign_key
          end
        when :add_check_constraint
          table, expression, options = args
          options ||= {}

          if !new_table?(table)
            if postgresql? && options[:validate] != false
              add_options = options.merge(validate: false)
              name = options[:name] || @migration.check_constraint_options(table, expression, options)[:name]
              validate_options = {name: name}

              return safe_add_check_constraint(table, expression, add_options, validate_options) if StrongMigrations.safe_by_default

              raise_error :add_check_constraint,
                add_check_constraint_code: command_str("add_check_constraint", [table, expression, add_options]),
                validate_check_constraint_code: command_str("validate_check_constraint", [table, validate_options])
            elsif mysql? || mariadb?
              raise_error :add_check_constraint_mysql
            end
          end
        when :validate_check_constraint
          if postgresql? && writes_blocked?
            raise_error :validate_check_constraint
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
          connection.execute "ANALYZE #{connection.quote_table_name(args[0].to_s)}"
        elsif mariadb? || mysql?
          connection.execute "ANALYZE TABLE #{connection.quote_table_name(args[0].to_s)}"
        end
      end

      result
    end

    private

    def set_timeouts
      if !@timeouts_set
        if StrongMigrations.statement_timeout
          statement =
            if postgresql?
              "SET statement_timeout TO #{connection.quote(postgresql_timeout(StrongMigrations.statement_timeout))}"
            elsif mysql?
              # use ceil to prevent no timeout for values under 1 ms
              "SET max_execution_time = #{connection.quote((StrongMigrations.statement_timeout.to_f * 1000).ceil)}"
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

    def connection
      @migration.connection
    end

    def version
      @migration.version
    end

    def safe?
      @safe || ENV["SAFETY_ASSURED"] || @migration.is_a?(ActiveRecord::Schema) ||
        (direction == :down && !StrongMigrations.check_down) || version_safe?
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
      target_version ||= StrongMigrations.target_version
      version =
        if target_version && StrongMigrations.developer_env?
          target_version.to_s
        else
          yield
        end
      Gem::Version.new(version)
    end

    def ar_version
      ActiveRecord::VERSION::STRING.to_f
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
          # lock timeout is an integer
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
        # use ceil to prevent no timeout for values under 1 ms
        (timeout.to_f * 1000).ceil
      end
    end

    def constraints(table_name)
      query = <<~SQL
        SELECT
          conname AS name,
          pg_get_constraintdef(oid) AS def
        FROM
          pg_constraint
        WHERE
          contype = 'c' AND
          convalidated AND
          conrelid = #{connection.quote(connection.quote_table_name(table_name))}::regclass
      SQL
      connection.select_all(query.squish).to_a
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

    def writes_blocked?
      query = <<~SQL
        SELECT
          relation::regclass::text
        FROM
          pg_locks
        WHERE
          mode IN ('ShareRowExclusiveLock', 'AccessExclusiveLock') AND
          pid = pg_backend_pid()
      SQL
      connection.select_all(query.squish).any?
    end

    def rewrite_blocks
      mysql? || mariadb? ? "writes" : "reads and writes"
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
