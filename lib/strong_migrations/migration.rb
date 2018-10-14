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
        when :remove_column
          raise_error :remove_column, model: args[0].to_s.classify, column: args[1].to_s.inspect
        when :remove_timestamps
          raise_error :remove_column
        when :change_table
          raise_error :change_table
        when :rename_table
          raise_error :rename_table
        when :rename_column
          raise_error :rename_column
        when :add_index
          columns = args[1]
          options = args[2] || {}
          if columns.is_a?(Array) && columns.size > 3 && !options[:unique]
            raise_error :add_index_columns
          end
          if postgresql? && options[:algorithm] != :concurrently && !@new_tables.to_a.include?(args[0].to_s)
            error_columns = Array(columns).map(&:to_sym)
            error_columns = error_columns.first if error_columns.size == 1
            raise_error :add_index, table: sym_str(args[0]), column: error_columns.inspect, options: options_str(options)
          end
        when :add_column
          type = args[2]
          options = args[3] || {}
          default = options[:default]

          if !default.nil? && !(postgresql? && postgresql_version >= 110000)
            raise_error :add_column_default, table: sym_str(args[0]), column: sym_str(args[1]), type: sym_str(type), options: options_str(options.except(:default)), default: default.inspect
          end

          if type.to_s == "json" && postgresql?
            if postgresql_version >= 90400
              raise_error :add_column_json
            else
              raise_error :add_column_json_legacy, table: connection.quote_table_name(args[0])
            end
          end
        when :change_column
          safe = false
          # assume Postgres 9.1+ since previous versions are EOL
          if postgresql? && args[2].to_s == "text"
            column = connection.columns(args[0]).find { |c| c.name.to_s == args[1].to_s }
            safe = column && column.type == :string
          end
          raise_error :change_column unless safe
        when :create_table
          options = args[1] || {}
          raise_error :create_table if options[:force]
          (@new_tables ||= []) << args[0].to_s
        when :add_reference, :add_belongs_to
          options = args[2] || {}
          index_value = options.fetch(:index, ActiveRecord::VERSION::MAJOR >= 5 ? true : false)
          if postgresql? && index_value
            error_columns = options[:polymorphic] ? [:"#{args[1]}_type", :"#{args[1]}_id"].inspect : sym_str("#{args[1]}_id")
            raise_error :add_reference, command: method, table: sym_str(args[0]), reference: sym_str(args[1]), column: error_columns, options: options_str(options.except(:index))
          end
        when :execute
          raise_error :execute
        when :change_column_null
          null = args[2]
          default = args[3]
          if !null && !default.nil?
            raise_error :change_column_null
          end
        end

        StrongMigrations.checks.each do |check|
          instance_exec(method, args, &check)
        end
      end

      result = super

      if StrongMigrations.auto_analyze && @direction == :up && postgresql? && method == :add_index
        connection.execute "ANALYZE VERBOSE #{connection.quote_table_name(args[0])}"
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

    def raise_error(message_key, vars = {})
      message = StrongMigrations.error_messages[message_key] || "Missing message"
      # escape % not followed by {
      stop!(message.gsub(/%(?!{)/, "%%") % vars)
    end

    def sym_str(v)
      v.to_sym.inspect
    end

    def options_str(options)
      str = String.new("")
      options.each do |k, v|
        str << ", #{k}: #{v.inspect}"
      end
      str
    end

    def stop!(message)
      wait_message = '
 __          __     _____ _______ _
 \ \        / /\   |_   _|__   __| |
  \ \  /\  / /  \    | |    | |  | |
   \ \/  \/ / /\ \   | |    | |  | |
    \  /\  / ____ \ _| |_   | |  |_|
     \/  \/_/    \_\_____|  |_|  (_)  #strong_migrations

'
      raise StrongMigrations::UnsafeMigration, "#{wait_message}#{message}\n"
    end
  end
end
