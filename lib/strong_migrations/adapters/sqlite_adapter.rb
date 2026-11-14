module StrongMigrations
  module Adapters
    class SQLiteAdapter < AbstractAdapter
      def name
        "SQLite"
      end

      def min_version
        # Active Record 7.2's minimum; newer Rails versions may require more.
        "3.8.0"
      end

      def server_version
        @server_version ||= target_version(nil) do
          select_all("SELECT sqlite_version()").first["sqlite_version()"]
        end
      end

      def rewrite_blocks
        "writes throughout the database"
      end
    end
  end
end
