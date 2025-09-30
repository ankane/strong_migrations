module StrongMigrations
  class Checker
    include SafeMethods

    attr_accessor :direction, :transaction_disabled, :timeouts_set

    class << self
      attr_accessor :safe
    end

    def initialize(migration)
      @migration = migration
      reset
    end

    def reset
      @new_tables = []
      @new_columns = []
      @timeouts_set = false
      @committed = false
      @transaction_disabled = false
      @skip_retries = false
    end

    def self.safety_assured
      previous_value = safe
      begin
        self.safe = true
        yield
      ensure
        self.safe = previous_value
      end
    end

    def connection
      @migration.connection
    end

    def version
      @migration.version
    end

    def perform(method, *args, &block)
      return yield if skip?

      check_adapter
      check_version_supported
      set_timeouts
      check_lock_timeout

      if !safe? || safe_by_default_method?(method)
        # TODO better pattern
        # see checks.rb for methods
        case method
        when :add_check_constraint
          check_add_check_constraint(*args)
        when :add_column
          check_add_column(*args)
        when :add_exclusion_constraint
          check_add_exclusion_constraint(*args)
        when :add_foreign_key
          if StrongMigrations.safe_by_default && safe_by_default_method?(method)
            return safe_add_foreign_key(*args)
          else
            check_add_foreign_key(*args)
          end
        when :add_index
          if StrongMigrations.safe_by_default && safe_by_default_method?(method)
            return safe_add_index(*args)
          else
            check_add_index(*args)
          end
        when :add_reference, :add_belongs_to
          check_add_reference(method, *args)
        when :add_unique_constraint
          check_add_unique_constraint(*args)
        when :change_column
          check_change_column(*args)
        when :change_column_default
          check_change_column_default(*args)
        when :change_column_null
          if StrongMigrations.safe_by_default && safe_by_default_method?(method)
            return safe_change_column_null(*args)
          else
            check_change_column_null(*args)
          end
        when :change_table
          check_change_table
        when :create_join_table
          check_create_join_table(*args)
        when :create_table
          check_create_table(*args)
        when :execute
          check_execute
        when :remove_column, :remove_columns, :remove_timestamps, :remove_reference, :remove_belongs_to
          check_remove_column(method, *args)
        when :remove_index
          if StrongMigrations.safe_by_default && safe_by_default_method?(method)
            return safe_remove_index(*args)
          else
            check_remove_index(*args)
          end
        when :rename_column
          check_rename_column
        when :rename_schema
          check_rename_schema
        when :rename_table
          check_rename_table
        when :validate_check_constraint
          check_validate_check_constraint
        when :validate_foreign_key
          check_validate_foreign_key
        when :commit_db_transaction
          # if committed, likely no longer in DDL transaction
          # and no longer eligible to be retried at migration level
          # okay to have false positives
          @committed = true
        end

        if !safe?
          # custom checks
          StrongMigrations.checks.each do |check|
            @migration.instance_exec(method, args, &check)
          end
        end
      end

      result =
        if retry_lock_timeouts?(method)
          # TODO figure out how to handle methods that generate multiple statements
          # like add_reference(table, ref, index: {algorithm: :concurrently})
          # lock timeout after first statement will cause retry to fail
          retry_lock_timeouts { perform_method(method, *args, &block) }
        else
          perform_method(method, *args, &block)
        end

      # outdated statistics + a new index can hurt performance of existing queries
      if StrongMigrations.auto_analyze && direction == :up && adds_index?(method, *args)
        adapter.analyze_table(args[0])
      end

      # Track new tables and columns
      case method
      when :create_table
        @new_tables << args[0].to_s
      when :add_column
        @new_columns << "#{args[0]}.#{args[1]}"
      end

      result
    end

    def perform_method(method, *args)
      if StrongMigrations.remove_invalid_indexes && direction == :up && method == :add_index && postgresql?
        remove_invalid_index_if_needed(*args)
      end
      yield
    end

    def retry_lock_timeouts(check_committed: false)
      retries = 0
      begin
        yield
      rescue ActiveRecord::LockWaitTimeout => e
        if retries < StrongMigrations.lock_timeout_retries && !(check_committed && @committed)
          retries += 1
          delay = StrongMigrations.lock_timeout_retry_delay
          @migration.say("Lock timeout. Retrying in #{delay} seconds...")
          sleep(delay)
          retry
        end
        raise e
      end
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def skip?
      StrongMigrations.skipped_databases.map(&:to_s).include?(db_config_name) ||
      @migration.reverting? ||
      version && version <= StrongMigrations.start_after ||
      safe? ||
      ENV["SAFETY_ASSURED"]
    end

    private

    def check_adapter
      return if defined?(@adapter_checked)

      if adapter.instance_of?(Adapters::AbstractAdapter)
        warn "[strong_migrations] Unsupported adapter: #{connection.adapter_name}. Use StrongMigrations.skip_database(#{db_config_name.to_sym.inspect}) to silence this warning."
      end

      @adapter_checked = true
    end

    def check_version_supported
      return if defined?(@version_checked)

      min_version = adapter.min_version
      if min_version
        version = adapter.server_version
        if version < Gem::Version.new(min_version)
          raise UnsupportedVersion, "#{adapter.name} version (#{version}) not supported in this version of Strong Migrations (#{StrongMigrations::VERSION})"
        end
      end

      @version_checked = true
    end

    def set_timeouts
      return if @timeouts_set

      if StrongMigrations.statement_timeout
        adapter.set_statement_timeout(StrongMigrations.statement_timeout)
      end
      if StrongMigrations.transaction_timeout
        adapter.set_transaction_timeout(StrongMigrations.transaction_timeout)
      end
      if StrongMigrations.lock_timeout
        adapter.set_lock_timeout(StrongMigrations.lock_timeout)
      end

      @timeouts_set = true
    end

    def check_lock_timeout
      return if defined?(@lock_timeout_checked)

      if StrongMigrations.lock_timeout_limit
        adapter.check_lock_timeout(StrongMigrations.lock_timeout_limit)
      end

      @lock_timeout_checked = true

      if !@transaction_disabled && postgresql?
        if StrongMigrations.lock_timeout.nil?
          say "IMPORTANT: No lock timeout set. This can block other queries."
          say "Set a lock timeout with StrongMigrations.lock_timeout = 10.seconds"
        end
      end
    end

    def safe?
      self.class.safe || ENV["SAFETY_ASSURED"] || (direction == :down && !StrongMigrations.check_down) || version_safe? || @migration.reverting?
    end

    def adapter
      @adapter ||= begin
        cls =
          case connection.adapter_name
          when /postg/i # PostgreSQL, PostGIS
            Adapters::PostgreSQLAdapter
          when /mysql|trilogy/i
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
      adapter.postgresql?
    end

    def mysql?
      adapter.mysql?
    end

    def mariadb?
      adapter.mariadb?
    end

    def db_config_name
      if connection.pool.respond_to?(:db_config)
        connection.pool.db_config.name
      else
        "primary"
      end
    end

    def retry_lock_timeouts?(method)
      (
        StrongMigrations.lock_timeout_retries > 0 &&
        !in_transaction? &&
        method != :transaction &&
        !@skip_retries
      )
    end

    def without_retries
      previous_value = @skip_retries
      begin
        @skip_retries = true
        yield
      ensure
        @skip_retries = previous_value
      end
    end

    def adds_index?(method, *args)
      case method
      when :add_index
        true
      when :add_reference, :add_belongs_to
        options = args.extract_options!
        !!options.fetch(:index, true)
      else
        false
      end
    end

    # REINDEX INDEX CONCURRENTLY leaves a new invalid index if it fails, so use remove_index instead
    def remove_invalid_index_if_needed(*args)
      options = args.extract_options!

      # ensures has same options as existing index
      # check args to avoid errors with index_exists?
      return unless args.size == 2 && connection.index_exists?(*args, options.merge(valid: false))

      table, columns = args
      index_name = options.fetch(:name, connection.index_name(table, columns))

      @migration.say("Attempting to remove invalid index")
      without_retries do
        # TODO pass index schema for extra safety?
        @migration.remove_index(table, {name: index_name}.merge(options.slice(:algorithm)))
      end
    end

    def new_table?(table)
      @new_tables.include?(table.to_s)
    end

    def new_column?(table, column)
      @new_columns.include?("#{table}.#{column}")
    end

    def say(message)
      @migration.say "\n#{message}"
    end

    def stop!(message, header: "Dangerous operation detected")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}"
    end

    # Check methods
    def check_add_column(table, column, type, options = {})
      default = options[:default]

      if !new_table?(table) && !new_column?(table, column)
        if type.to_s == "json" && postgresql?
          if adapter.min_version?("9.4")
            stop! StrongMigrations.error_messages[:add_column_json]
          else
            stop! StrongMigrations.error_messages[:add_column_json_legacy] % { model: table.classify, base_model: model_base_class, table: table }
          end
        end

        if !default.nil? && !(postgresql? && adapter.min_version?("11"))
          if default.is_a?(Proc)
            default = default.call
          end

          stop! StrongMigrations.error_messages[:add_column_default] % {
            migration_name: @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, ""),
            migration_suffix: migration_suffix,
            add_command: command_str("add_column", [table, column, type]),
            change_command: command_str("change_column_default", [table, column, default]),
            remove_command: command_str("remove_column", [table, column]),
            code: backfill_code(table, column, default)
          }
        end
      end
    end

    def check_add_reference(method, table, reference, options = {})
      index_value = options.fetch(:index, true)
      concurrently_set = index_value.is_a?(Hash) && index_value[:algorithm] == :concurrently

      if !new_table?(table) && index_value && postgresql? && !concurrently_set
        stop! StrongMigrations.error_messages[:add_reference] % {
          migration_name: @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, ""),
          migration_suffix: migration_suffix,
          reference_command: command_str("add_reference", [table, reference, options.merge(index: false)]),
          index_command: command_str("add_index", [table, "#{reference}_id", {algorithm: :concurrently}])
        }
      end
    end

    def check_add_index(table, columns, options = {})
      if !new_table?(table) && postgresql? && options[:algorithm] != :concurrently
        stop! StrongMigrations.error_messages[:add_index] % {
          migration_name: @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, ""),
          migration_suffix: migration_suffix,
          command: command_str("add_index", [table, columns, options.merge(algorithm: :concurrently)])
        }
      end

      # Check for too many columns
      columns = Array(columns)
      if columns.size > 3
        stop! StrongMigrations.error_messages[:add_index_columns]
      end
    end

    def check_add_foreign_key(from_table, to_table = nil, options = {})
      if postgresql? && options[:validate] != false
        if to_table.is_a?(Hash)
          options = to_table
          to_table = options[:to_table] if options[:to_table]
        end

        to_table ||= from_table.to_s.singularize.foreign_key.gsub(/_id\z/, "").pluralize

        add_options = options.merge(validate: false)
        validate_options = {column: options[:column] || "#{to_table.to_s.singularize}_id"}
        if options[:name]
          validate_options[:name] = options[:name]
        end

        migration_name = @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, "")

        stop! StrongMigrations.error_messages[:add_foreign_key] % {
          migration_name: migration_name,
          migration_suffix: migration_suffix,
          add_foreign_key_code: command_str("add_foreign_key", [from_table, to_table, add_options]),
          validate_migration_name: "Validate#{migration_name}",
          validate_foreign_key_code: command_str("validate_foreign_key", [from_table, validate_options])
        }
      end
    end

    def check_change_column(table, column, type, options = {})
      stop! StrongMigrations.error_messages[:change_column]
    end

    def check_change_column_default(*args)
      # Implementation for change_column_default check
    end

    def check_change_column_null(table, column, null, default = nil)
      if !new_table?(table) && !new_column?(table, column) && !null && !default.nil?
        stop! StrongMigrations.error_messages[:change_column_null] % {
          migration_name: @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, ""),
          migration_suffix: migration_suffix,
          code: backfill_code(table, column, default)
        }
      end
    end

    def check_change_table(*args)
      stop! StrongMigrations.error_messages[:change_table]
    end

    def check_create_join_table(*args)
      # Implementation for create_join_table check
    end

    def check_create_table(table, options = {})
      if options[:force]
        stop! StrongMigrations.error_messages[:create_table]
      end
    end

    def check_execute(*args)
      stop! StrongMigrations.error_messages[:execute]
    end

    def check_remove_column(method, table, *columns)
      columns.each do |column|
        model = table.to_s.classify.constantize rescue nil
        if model && model < ActiveRecord::Base

          if model.respond_to?(:ignored_columns) && !model.ignored_columns.include?(column.to_s)
            columns_str = columns.size > 1 ? "s" : ""

            message = StrongMigrations.error_messages[:remove_column] % {
              model: model.name,
              base_model: model_base_class,
              code: columns.map { |c| "self.ignored_columns += [#{c.to_s.inspect}]" }.join("\n  "),
              column_suffix: columns_str,
              migration_name: @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, ""),
              migration_suffix: migration_suffix,
              command: columns.map { |c| "remove_column #{table.inspect}, #{c.to_s.inspect}" }.join("\n    ")
            }

            stop! message
          end
        end
      end
    end

    def check_remove_index(*args)
      # Implementation for remove_index check
    end

    def check_rename_column(*args)
      stop! StrongMigrations.error_messages[:rename_column]
    end

    def check_rename_schema(*args)
      # Implementation for rename_schema check
    end

    def check_rename_table(*args)
      stop! StrongMigrations.error_messages[:rename_table]
    end

    def check_add_check_constraint(table, expression, options = {})
      if !new_table?(table)
        if postgresql? && options[:validate] != false
          add_options = options.merge(validate: false)
          name = options[:name] || "#{table}_#{expression.tr(' ', '_').downcase}_check"
          validate_options = {name: name}

          migration_name = @migration.class.name.sub(/\AMigration/, "").sub(/\A[^A-Z]*/, "")

          stop! StrongMigrations.error_messages[:add_check_constraint] % {
            migration_name: migration_name,
            migration_suffix: migration_suffix,
            add_check_constraint_code: command_str("add_check_constraint", [table, expression, add_options]),
            validate_check_constraint_code: command_str("validate_check_constraint", [table, validate_options])
          }
        elsif mysql? || mariadb?
          stop! "Adding a check constraint blocks writes in MySQL and MariaDB."
        end
      end
    end

    def check_add_unique_constraint(table, columns = nil, options = {})
      if postgresql?
        stop! "Adding a unique constraint creates a unique index, which blocks reads and writes."
      end
    end

    def check_add_exclusion_constraint(table, expression, options = {})
      if postgresql?
        stop! "Adding an exclusion constraint blocks reads and writes while every row is checked."
      end
    end

    def check_validate_check_constraint(*args)
      # Implementation for validate_check_constraint check
    end

    def check_validate_foreign_key(*args)
      # Implementation for validate_foreign_key check
    end

    # Helper methods
    def migration_suffix
      if ActiveRecord::VERSION::MAJOR >= 5
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      else
        ""
      end
    end

    def model_base_class
      if ActiveRecord::VERSION::MAJOR >= 5
        "ApplicationRecord"
      else
        "ActiveRecord::Base"
      end
    end

    def command_str(command, args)
      str_args = args[0..-2].map(&:inspect) + [args[-1].is_a?(Hash) ? args[-1].map { |k, v| "#{k}: #{v.inspect}" }.join(", ") : args[-1].inspect]
      "#{command} #{str_args.join(", ")}"
    end

    def backfill_code(table, column, default)
      model = table.to_s.classify
      "#{model}.unscoped.in_batches.update_all #{column}: #{default.inspect}"
    end

    def in_transaction?
      connection.open_transactions > 0
    end
  end
end