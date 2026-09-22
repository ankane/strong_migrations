module StrongMigrations
  module SchemaDumper
    def initialize(connection, ...)
      return super unless StrongMigrations.alphabetize_schema

      super(WrappedConnection.new(connection), ...)
    end
  end

  class WrappedConnection
    delegate_missing_to :@connection

    def initialize(connection)
      @connection = connection
    end

    def columns(...)
      columns = @connection.columns(...)
      if ActiveRecord::VERSION::STRING.to_f >= 8.2 && columns.is_a?(Hash)
        columns.transform_values { |v| v.sort_by(&:name) }
      else
        columns.sort_by(&:name)
      end
    end

    # forward private methods with send
    # method_missing cannot tell how method was called
    # this is not ideal, but other solutions have drawbacks
    def send(name, ...)
      if respond_to?(name, true)
        super
      else
        @connection.send(name, ...)
      end
    end
  end
end
