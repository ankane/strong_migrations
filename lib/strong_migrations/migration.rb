module StrongMigrations
  module Migration
    def migrate(direction)
      strong_migrations_checker.direction = direction
      super
      connection.begin_db_transaction if strong_migrations_checker.transaction_disabled
    end

    def method_missing(method, *args)
      return super if is_a?(ActiveRecord::Schema)

      # Active Record 7.0.2+ versioned schema
      return super if defined?(ActiveRecord::Schema::Definition) && is_a?(ActiveRecord::Schema::Definition)

      catch(:safe) do
        strong_migrations_checker.perform(method, *args) do
          super
        end
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

    def connection
      conn = super
      if StrongMigrations.lock_timeout_retries > 0
        if !conn.instance_variable_defined?(:@strong_migrations_checker)
          m = Module.new
          m.class_eval do
            def execute(*, **)
              return super if open_transactions > 0

              instance_variable_get(:@strong_migrations_checker).with_lock_timeout_retries do
                super
              end
            end
          end
          conn.singleton_class.prepend(m)
        end
        # update checker
        conn.instance_variable_set(:@strong_migrations_checker, strong_migrations_checker)
      end
      conn
    end

    private

    def strong_migrations_checker
      @strong_migrations_checker ||= StrongMigrations::Checker.new(self)
    end
  end
end
