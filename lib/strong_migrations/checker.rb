module StrongMigrations
  class Checker
    include Checks
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
      check_version_supported
      set_timeouts
      check_lock_timeout

      if !safe? || safe_by_default_method?(method)
        # TODO better pattern
        case method
        when :remove_column, :remove_columns, :remove_timestamps, :remove_reference, :remove_belongs_to
          check_remove_column(method, args)
        when :change_table
          check_change_table
        when :rename_table
          check_rename_table
        when :rename_column
          check_rename_column
        when :add_index
          check_add_index(args)
        when :remove_index
          check_remove_index(args)
        when :add_column
          check_add_column(args)
        when :change_column
          check_change_column(args)
        when :create_table
          check_create_table(args)
        when :add_reference, :add_belongs_to
          check_add_reference(method, args)
        when :execute
          check_execute
        when :change_column_null
          check_change_column_null(args)
        when :add_foreign_key
          check_add_foreign_key(args)
        when :validate_foreign_key
          check_validate_foreign_key
        when :add_check_constraint
          check_add_check_constraint(args)
        when :validate_check_constraint
          check_validate_check_constraint
        end

        # custom checks
        StrongMigrations.checks.each do |check|
          @migration.instance_exec(method, args, &check)
        end
      end

      result = yield

      # outdated statistics + a new index can hurt performance of existing queries
      if StrongMigrations.auto_analyze && direction == :up && method == :add_index
        adapter.analyze_table(args[0])
      end

      result
    end

    private

    def set_timeouts
      if !@timeouts_set
        if StrongMigrations.statement_timeout
          adapter.set_statement_timeout(StrongMigrations.statement_timeout)
        end
        if StrongMigrations.lock_timeout
          adapter.set_lock_timeout(StrongMigrations.lock_timeout)
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
      @safe || ENV["SAFETY_ASSURED"] || (direction == :down && !StrongMigrations.check_down) || version_safe?
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def adapter
      @adapter ||= begin
        cls =
          case connection.adapter_name
          when /postg/i # PostgreSQL, PostGIS
            Adapters::PostgreSQLAdapter
          when /mysql/i
            if connection.try(:mariadb?)
              Adapters::MariaDBAdapter
            else
              Adapters::MySQLAdapter
            end
          else
            Adapters::AbstractAdapter
          end

        cls.new(self)
      end
    end

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

    def check_lock_timeout
      limit = StrongMigrations.lock_timeout_limit

      if limit && !@lock_timeout_checked
        adapter.check_lock_timeout(limit)
        @lock_timeout_checked = true
      end
    end

    # TODO raise error in 0.9.0
    def check_version_supported
      return if defined?(@version_checked)

      min_version = adapter.min_version
      if min_version
        version = adapter.server_version
        if version < Gem::Version.new(min_version)
          warn "[strong_migrations] #{adapter.name} version (#{version}) not supported in this version of Strong Migrations (#{StrongMigrations::VERSION})"
        end
      end

      @version_checked = true
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
