module StrongMigrations
  class TableDefinition
    def initialize(ar_table_definition)
      @ar_table_definition = ar_table_definition
    end

    def method_missing(method, *args, **kwargs)
      p "StrongMigrations::TableDefinition method_missing called with method: #{method} and args: #{args} and kwargs: #{kwargs}"

      @ar_table_definition.send(method, *args, **kwargs)
    end
  end
end
