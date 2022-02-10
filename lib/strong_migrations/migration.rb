module StrongMigrations
  module Migration
    def migrate(direction)
      strong_migrations_checker.direction = direction
      super
      connection.begin_db_transaction if strong_migrations_checker.transaction_disabled
    end

    def method_missing(method, *args)
      return super if schema_migration?

      strong_migrations_checker.perform(method, *args) do
        super
      end
    end
    ruby2_keywords(:method_missing) if respond_to?(:ruby2_keywords, true)

    def safety_assured
      strong_migrations_checker.safety_assured do
        yield
      end
    end

    def stop!(message, header: "Custom check")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}\n"
    end

    private

    def schema_migration?
      is_a?(ActiveRecord::Schema) || (
        Object.const_defined?('ActiveRecord::Schema::Definition') &&
          is_a?(ActiveRecord::Schema::Definition)
      )
    end

    def strong_migrations_checker
      @strong_migrations_checker ||= StrongMigrations::Checker.new(self)
    end
  end
end
