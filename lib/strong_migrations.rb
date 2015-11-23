require "active_record"
require "strong_migrations/version"
require "strong_migrations/unsafe_migration"
require "strong_migrations/migration"

ActiveRecord::Migration.send(:prepend, StrongMigrations::Migration)
