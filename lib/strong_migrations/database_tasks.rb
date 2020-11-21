module StrongMigrations
  module DatabaseTasks
    def migrate
      super
    rescue => e
      lock_messages = ["canceling statement due to lock timeout", "Lock wait timeout exceeded"]
      lock_timeout = e.cause && lock_messages.any? { |m| e.cause.message.include?(m) }

      if e.cause.is_a?(StrongMigrations::Error) || lock_timeout
        # strip cause and clean backtrace
        def e.cause
          nil
        end

        if lock_timeout
          def e.message
            <<~EOS
              #{super.split("\n").first}

              === Lock timeout detected #strong_migrations ===

              This typically happens when a table is busy.
              Try again at a lower traffic time.

            EOS
          end
        else
          def e.message
            super.sub("\n\n\n", "\n\n") + "\n"
          end
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
