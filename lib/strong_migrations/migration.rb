module StrongMigrations
  module Migration
    def safety_assured
      previous_value = @safe
      begin
        @safe = true
        yield
      ensure
        @safe = previous_value
      end
    end

    def migrate(direction)
      @checker = StrongMigrations::Checker.new(self, direction: direction)
      super
    end

    def method_missing(method, *args)
      if @checker
        @checker.perform(@safe, method, *args) do
          super
        end
      else
        super
      end
    end

    def stop!(message, header: "Custom check")
      raise StrongMigrations::UnsafeMigration, "\n=== #{header} #strong_migrations ===\n\n#{message}\n"
    end
  end
end
