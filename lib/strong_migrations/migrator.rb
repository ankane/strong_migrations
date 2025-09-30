module StrongMigrations
  module Migrator
    def ddl_transaction(migration, *args)
      return super unless StrongMigrations.lock_timeout_retries > 0 && use_transaction?(migration)

      # handle MigrationProxy class
      migration = migration.send(:migration) if !migration.is_a?(ActiveRecord::Migration) && migration.respond_to?(:migration, true)

      checker = migration.send(:strong_migrations_checker)
      return super if checker.skip?

      # retry migration since the entire transaction needs to be rerun
      checker.retry_lock_timeouts(check_committed: true) do
        # failed transaction reverts timeout, so need to re-apply
        checker.reset

        super(migration, *args)
      end
    end
  end
end

# Hook into migrator for Rails 5+
if defined?(ActiveRecord::Migrator) && ActiveRecord::VERSION::MAJOR >= 5
  ActiveRecord::Migrator.prepend(StrongMigrations::Migrator)
end