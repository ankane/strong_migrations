module StrongMigrations
  module Migration
    def migrate(direction)
      strong_migrations_checker.direction = direction
      super
      connection.begin_db_transaction if strong_migrations_checker.transaction_disabled
    end

    def method_missing(method, *args)
      return super if is_a?(ActiveRecord::Schema) || is_a?(ActiveRecord::Schema::Definition)

      catch(:safe) do
        strong_migrations_checker.perform(method, *args) do
          super
        end
      end
    end
    # same as ActiveRecord::Migration
    ruby2_keywords(:method_missing)

    def revert(*)
      if strong_migrations_checker.version_safe?
        safety_assured { super }
      else
        super
      end
    end

    def safety_assured
      strong_migrations_checker.class.safety_assured do
        yield
      end
    end

    def stop!(message, header: "Custom check")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}\n"
    end

    private

    def strong_migrations_checker
      @strong_migrations_checker ||= StrongMigrations::Checker.new(self)
    end
  end
end
