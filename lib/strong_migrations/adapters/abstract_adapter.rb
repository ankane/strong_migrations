module StrongMigrations
  module Adapters
    class AbstractAdapter
      def initialize(checker)
        @checker = checker
      end

      def connection
        @checker.connection
      end

      def postgresql?
        false
      end

      def mysql?
        false
      end

      def mariadb?
        false
      end

      def name
        connection.adapter_name
      end

      def min_version
      end

      def set_statement_timeout(timeout)
        # do nothing
      end

      def set_transaction_timeout(timeout)
        # do nothing
      end

      def set_lock_timeout(timeout)
        # do nothing
      end

      def check_lock_timeout(limit)
        # do nothing
      end

      def add_column_default_safe?
        false
      end

      def change_type_safe?(table, column, type, options, existing_column, existing_type)
        false
      end

      def rewrite_blocks
        "reads and writes"
      end

      def auto_incrementing_types
        ["primary_key"]
      end

      def max_constraint_name_length
      end

      def server_version
        @server_version ||= begin
          target_version(StrongMigrations.target_version) ||
            connection.select_all("SELECT version()").first["version"]
        rescue
          nil
        end
      end

      def min_version?(version)
        return false unless server_version

        if version.is_a?(String)
          Gem::Version.new(server_version_num) >= Gem::Version.new(version)
        else
          server_version_num >= version
        end
      end

      private

      def select_all(statement)
        connection.select_all(statement)
      end

      def server_version_num
        @server_version_num ||= begin
          version = server_version
          if postgresql?
            version.split(" ").first
          elsif mysql? || mariadb?
            version.split("-").first
          else
            version
          end
        end
      end

      def target_version(target_version)
        target_version ||= StrongMigrations.target_version
        version =
          if target_version && StrongMigrations.developer_env?
            if target_version.is_a?(Hash)
              # Rails 4.2 compatible database name access
              db_name = if connection.respond_to?(:database_name)
                          connection.database_name
                        else
                          connection.current_database
                        end
              target_version.stringify_keys.fetch(db_name) do
                # error class is not shown in db:migrate output so ensure message is descriptive
                raise StrongMigrations::Error, "StrongMigrations.target_version is not configured for :#{db_name} database"
              end.to_s
            else
              target_version.to_s
            end
          else
            yield if block_given?
          end
        version ? Gem::Version.new(version) : nil
      end

      def database_name
        if connection.respond_to?(:database_name)
          connection.database_name
        else
          connection.current_database
        end
      end
    end
  end
end
