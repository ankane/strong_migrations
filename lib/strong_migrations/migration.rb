module StrongMigrations
  module Migration
    def safety_assured
      StrongMigrations::Checker.safety_assured do
        yield
      end
    end

    def migrate(direction)
      @strong_migrations_checker = StrongMigrations::Checker.new(self)
      @strong_migrations_checker.direction = direction
      super
      connection.begin_db_transaction if strong_migrations_checker.transaction_disabled
    end

    def method_missing(method, *args, &block)
      return super if is_a?(ActiveRecord::Schema) || is_a?(ActiveRecord::Schema::Definition)

      if @strong_migrations_checker
        catch(:safe) do
          @strong_migrations_checker.perform(method, *args) do
            super
          end
        end
      else
        super
      end
    end
    # same as ActiveRecord::Migration
    if respond_to?(:ruby2_keywords, true)
      ruby2_keywords(:method_missing)
    end

    def revert(*)
      if strong_migrations_checker.version_safe?
        safety_assured { super }
      else
        super
      end
    end

    def disable_ddl_transaction!
      if @strong_migrations_checker
        @strong_migrations_checker.transaction_disabled = true
      end
      super
    end

    # support disable_ddl_transaction! being called before method_missing
    def method_added(method)
      if method == :change && @strong_migrations_checker
        @strong_migrations_checker.transaction_disabled = true
      end
      super
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