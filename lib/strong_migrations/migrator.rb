module StrongMigrations
  module Migrator
    def ddl_transaction(migration, *)
      if use_transaction?(migration)
        # retry migration since the entire transaction needs to be rerun
        migration.send(:strong_migrations_checker).with_lock_timeout_retries do
          super
        end
      else
        super
      end
    end
  end
end
