module StrongMigrations
  module Util
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

    def quote_identifiers(statement, identifiers)
      # not all identifiers are tables, but this method of quoting should be fine
      statement % identifiers.map { |v| connection.quote_table_name(v) }
    end
  end
end
