module StrongMigrations
  module Migration
    def initialize(*args)
      super
      @checker = StrongMigrations::Checker.new(self)
    end

    def migrate(direction)
      @checker.direction = direction
      super
    end

    def method_missing(method, *args)
      @checker.perform(method, *args) do
        super
      end
    end

    def safety_assured
      @checker.safety_assured do
        yield
      end
    end

    def stop!(message, header: "Custom check")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}\n"
    end
  end
end
