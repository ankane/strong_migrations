module StrongMigrations
  module Util
    def connection
      ActiveRecord::Base.connection
    end

    def postgresql?
      %w(PostgreSQL PostGIS).include?(connection.adapter_name)
    end

    def mysql?
      connection.adapter_name == "Mysql2"
    end

    def postgresql_version
      @postgresql_version ||= begin
        target_version = StrongMigrations.target_postgresql_version
        if target_version && defined?(Rails) && (Rails.env.development? || Rails.env.test?)
          # we only need major version right now
          target_version.to_i * 10000
        else
          connection.postgresql_version
        end
      end
    end

    def quote_identifiers(statement, identifiers)
      # not all identifiers are tables, but this method of quoting should be fine
      statement % identifiers.map { |v| connection.quote_table_name(v) }
    end
  end
end
