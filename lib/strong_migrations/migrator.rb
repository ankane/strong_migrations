module StrongMigrations
  module Migrator
    def ddl_transaction(migration, *args)
      if use_transaction?(migration) && StrongMigrations.lock_timeout_retries > 0 && StrongMigrations.lock_timeout_retry_transactions
        # handle MigrationProxy class
        migration = migration.send(:migration) if migration.respond_to?(:migration, true)

        # retry migration since the entire transaction needs to be rerun
        checker = migration.send(:strong_migrations_checker)
        checker.retry_lock_timeouts(check_committed: true) do
          # failed transaction reverts timeout, so need to re-apply
          checker.timeouts_set = false

          super(migration, *args)
        end
      else
        super
      end
    end
  end
end
