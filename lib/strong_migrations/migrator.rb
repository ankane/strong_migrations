module StrongMigrations
  module Migrator
    def ddl_transaction(migration, *args)
      if use_transaction?(migration) && StrongMigrations.lock_timeout_retries > 0
        # handle MigrationProxy class
        migration = migration.send(:migration) if migration.respond_to?(:migration, true)

        # retry migration since the entire transaction needs to be rerun
        migration.send(:strong_migrations_checker).with_lock_timeout_retries do
          super(migration, *args)
        end
      else
        super
      end
    end
  end
end
