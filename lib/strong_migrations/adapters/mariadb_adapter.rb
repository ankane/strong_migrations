module StrongMigrations
  module Adapters
    class MariaDBAdapter < MySQLAdapter
      def name
        "MariaDB"
      end

      def min_version
        "10.5"
      end

      def server_version
        @server_version ||= begin
          target_version(StrongMigrations.target_mariadb_version) do
            select_all("SELECT VERSION()").first["VERSION()"].split("-").first
          end
        end
      end

      def set_statement_timeout(timeout)
        # fix deprecation warning with Active Record 7.1
        timeout = timeout.value if timeout.is_a?(ActiveSupport::Duration)

        select_all("SET max_statement_time = #{connection.quote(timeout)}")
      end

      def add_column_default_safe?
        true
      end
    end
  end
end
