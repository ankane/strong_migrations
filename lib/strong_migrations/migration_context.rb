module StrongMigrations
  module MigrationContext
    def up(...)
      super
    rescue => e
      strong_migrations_process_exception(e)
    end

    def down(...)
      super
    rescue => e
      strong_migrations_process_exception(e)
    end

    def run(...)
      super
    rescue => e
      strong_migrations_process_exception(e)
    end

    private

    def strong_migrations_process_exception(e)
      if e.cause.is_a?(StrongMigrations::Error)
        # strip cause and clean backtrace
        def e.cause
          nil
        end

        def e.message
          super.sub("\n\n\n", "\n\n") + "\n"
        end

        unless Rake.application.options.trace
          def e.backtrace
            bc = ActiveSupport::BacktraceCleaner.new
            bc.add_silencer { |line| line =~ /strong_migrations/ }
            bc.clean(super)
          end
        end
      end

      raise e
    end
  end
end
