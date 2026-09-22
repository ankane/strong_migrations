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
      @connection.columns(...).then do |cols_or_hash|
        if cols_or_hash.is_a?(Hash)
          cols_or_hash.transform_values { |cols| cols.sort_by(&:name) }
        else
          cols_or_hash.sort_by(&:name)
        end
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
