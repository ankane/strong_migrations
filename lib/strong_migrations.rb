# dependencies
require "active_support"

# adapters
require "strong_migrations/adapters/abstract_adapter"
require "strong_migrations/adapters/mysql_adapter"
require "strong_migrations/adapters/mariadb_adapter"
require "strong_migrations/adapters/postgresql_adapter"

# modules
require "strong_migrations/checks"
require "strong_migrations/safe_methods"
require "strong_migrations/checker"
require "strong_migrations/database_tasks"
require "strong_migrations/migration"
require "strong_migrations/migrator"
require "strong_migrations/version"

# integrations
require "strong_migrations/railtie" if defined?(Rails)

module StrongMigrations
  class Error < StandardError; end
  class UnsafeMigration < Error; end
  class UnsupportedVersion < Error; end

  class << self
    attr_accessor :auto_analyze, :start_after, :checks, :error_messages,
      :target_postgresql_version, :target_mysql_version, :target_mariadb_version,
      :enabled_checks, :lock_timeout, :statement_timeout, :check_down, :target_version,
      :safe_by_default, :target_sql_mode, :lock_timeout_retries, :lock_timeout_retry_delay,
      :lock_timeout_retry_transactions
    attr_writer :lock_timeout_limit
  end
  self.auto_analyze = false
  self.start_after = 0
  self.lock_timeout_retries = 0
  self.lock_timeout_retry_delay = 5 # seconds
  self.lock_timeout_retry_transactions = true
  self.checks = []
  self.safe_by_default = false
  self.check_down = false

  # private
  def self.developer_env?
    defined?(Rails) && (Rails.env.development? || Rails.env.test?)
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
end

# load error messages
require "strong_migrations/error_messages"

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(StrongMigrations::Migration)
  ActiveRecord::Migrator.prepend(StrongMigrations::Migrator)

  if defined?(ActiveRecord::Tasks::DatabaseTasks)
    ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(StrongMigrations::DatabaseTasks)
  end
end
