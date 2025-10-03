module StrongMigrations
  module Migrator
    def ddl_transaction(migration, ...)
      retries = StrongMigrations.lock_timeout_retries > 0 && use_transaction?(migration)
      return super unless retries || StrongMigrations.transaction_timeout

      # handle MigrationProxy class
      migration = migration.send(:migration) if !migration.is_a?(ActiveRecord::Migration) && migration.respond_to?(:migration, true)

      checker = migration.send(:strong_migrations_checker)
      return super if checker.skip?

      checker.set_transaction_timeout
      return super unless retries

      # retry migration since the entire transaction needs to be rerun
      checker.retry_lock_timeouts(check_committed: true) do
        # failed transaction reverts timeout, so need to re-apply
        checker.reset

        super(migration, ...)
      end
    end
  end
end
