module StrongMigrations
  module SchemaDumper
    def initialize(connection, *args)
      return super unless StrongMigrations.alphabetize_schema

      super(WrappedConnection.new(connection), *args)
    end
  end

  class WrappedConnection
    # For Ruby 2.2 compatibility, we can't use delegate_missing_to
    def initialize(connection)
      @connection = connection
    end

    def columns(*args)
      @connection.columns(*args).sort_by(&:name)
    end

    def method_missing(method, *args, &block)
      if @connection.respond_to?(method)
        @connection.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @connection.respond_to?(method, include_private) || super
    end

    # Forward private methods with send
    def send(name, *args, &block)
      if respond_to?(name, true)
        super
      else
        @connection.send(name, *args, &block)
      end
    end
  end
end

# Hook into the schema dumper
if defined?(ActiveRecord::SchemaDumper)
  ActiveRecord::SchemaDumper.prepend(StrongMigrations::SchemaDumper)
end