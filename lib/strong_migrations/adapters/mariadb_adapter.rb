module StrongMigrations
  module Adapters
    class MariadbAdapter < MysqlAdapter
      def mariadb?
        true
      end

      def mysql?
        false
      end

      def name
        "MariaDB"
      end

      def min_version
        "10.5"
      end

      def server_version
        @server_version ||= begin
          target_version(StrongMigrations.target_mariadb_version) ||
            target_version(StrongMigrations.target_version) ||
            begin
              select_all("SELECT VERSION()").first["VERSION()"].split("-").first
            rescue
              connection.select_all("SELECT version()").first["version()"]
            end
        rescue
          nil
        end
      end

      def set_statement_timeout(timeout)
        # MariaDB 10.1.1+
        if min_version?("10.1.1")
          # fix deprecation warning with Active Record 7.1
          timeout = timeout.value if timeout.is_a?(ActiveSupport::Duration)

          connection.execute("SET max_statement_time = #{timeout_value(timeout, "s")}")
        end
      end

      def add_column_default_safe?
        true
      end

      private

      def timeout_value(timeout, suffix = nil)
        if timeout.is_a?(String)
          if suffix == "s"
            timeout.to_i / 1000
          else
            timeout.to_i
          end
        else
          timeout.to_i / (suffix == "s" ? 1000 : 1)
        end
      end
    end
  end
end
