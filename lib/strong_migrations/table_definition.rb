module StrongMigrations
  class TableDefinition
    def initialize(ar_table_definition, migration, checker)
      @ar_table_definition = ar_table_definition
      @migration = migration
      @checker = checker
    end

    def method_missing(method, *args, **kwargs)
      return super if is_a?(ActiveRecord::Schema)

      # Active Record 7.0.2+ versioned schema
      return super if defined?(ActiveRecord::Schema::Definition) && is_a?(ActiveRecord::Schema::Definition)

      unless @checker.safe?
        StrongMigrations.table_checks.each do |check|
          @migration.instance_exec(method, args, kwargs, &check)
        end
      end
      @ar_table_definition.send(method, *args, **kwargs)
    end

    def safety_assured(&block)
      @checker.class.safety_assured(&block)
    end
  end
end
