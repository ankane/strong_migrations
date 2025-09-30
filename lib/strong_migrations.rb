# dependencies
require "active_support"

# adapters
require "strong_migrations/adapters/abstract_adapter"
require "strong_migrations/adapters/mysql_adapter"
require "strong_migrations/adapters/mariadb_adapter"
require "strong_migrations/adapters/postgresql_adapter"

# modules
require "strong_migrations/safe_methods"
require "strong_migrations/checker"
require "strong_migrations/schema_dumper"
require "strong_migrations/migrator"
require "strong_migrations/migration_context"
require "strong_migrations/database_tasks"
require "strong_migrations/migration"
require "strong_migrations/railtie" if defined?(Rails)
require "strong_migrations/unsafe_migration"
require "strong_migrations/version"

module StrongMigrations
  class Error < StandardError; end

  class << self
    attr_accessor :auto_analyze, :start_after, :checks, :error_messages,
      :target_postgresql_version, :target_mysql_version, :target_mariadb_version,
      :enabled_checks, :lock_timeout, :statement_timeout, :check_down, :target_version,
      :safe_by_default, :target_sql_mode, :lock_timeout_retries, :lock_timeout_retry_delay,
      :alphabetize_schema, :skipped_databases, :remove_invalid_indexes, :transaction_timeout
    attr_writer :lock_timeout_limit
  end
  self.auto_analyze = false
  self.start_after = 0
  self.lock_timeout_retries = 0
  self.lock_timeout_retry_delay = 10 # seconds
  self.checks = []
  self.safe_by_default = false
  self.check_down = false
  self.alphabetize_schema = false
  self.skipped_databases = []
  self.remove_invalid_indexes = false
  self.enabled_checks = {}

  # private
  def self.developer_env?
    env == "development" || env == "test"
  end

  # private
  def self.env
    if defined?(Rails.env)
      Rails.env
    else
      # default to production for safety
      ENV["RACK_ENV"] || "production"
    end
  end

  def self.lock_timeout_limit
    unless defined?(@lock_timeout_limit)
      @lock_timeout_limit = developer_env? ? false : 10
    end
    @lock_timeout_limit
  end

  def self.add_check(&block)
    checks << block
  end

  def self.enable_check(check, start_after: nil)
    enabled_checks[check] = {start_after: start_after}
  end

  def self.disable_check(check)
    enabled_checks.delete(check)
  end

  def self.check_enabled?(check, version: nil)
    if enabled_checks[check]
      start_after = enabled_checks[check][:start_after] || StrongMigrations.start_after
      !version || version > start_after
    else
      false
    end
  end

  def self.skip_database(database)
    self.skipped_databases << database
  end
end

# load error messages
require_relative "strong_migrations/error_messages"

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(StrongMigrations::Migration)
  if defined?(ActiveRecord::MigrationContext)
    ActiveRecord::MigrationContext.prepend(StrongMigrations::MigrationContext)
  end
  if defined?(ActiveRecord::Migrator) && ActiveRecord::VERSION::MAJOR >= 5
    ActiveRecord::Migrator.prepend(StrongMigrations::Migrator)
  end

  require_relative "strong_migrations/schema_dumper"
  if defined?(ActiveRecord::SchemaDumper)
    ActiveRecord::SchemaDumper.prepend(StrongMigrations::SchemaDumper)
  end
end