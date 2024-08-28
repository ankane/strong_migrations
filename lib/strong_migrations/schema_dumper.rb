module StrongMigrations
  module SchemaDumper
    extend ActiveSupport::Concern

    prepended do
      alias original_initialize initialize

      def initialize(connection, *args, **options)
        return original_initialize(connection, *args, **options) unless StrongMigrations.alphabetize_schema

        original_initialize(WrappedConnection.new(connection), *args, **options)
      end
    end
  end

  class WrappedConnection
    delegate_missing_to :@connection

    def initialize(connection)
      @connection = connection
    end

    def columns(*args, **options)
      @connection.columns(*args, **options).sort_by(&:name)
    end
  end
end
