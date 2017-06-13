require "active_record"
require "strong_migrations/version"
require "strong_migrations/unsafe_migration"
require "strong_migrations/migration"
require "strong_migrations/railtie" if defined?(Rails)

module StrongMigrations
  class << self
    attr_accessor :auto_analyze, :start_after
  end
  self.auto_analyze = false
  self.start_after = 0
end

ActiveRecord::Migration.send(:prepend, StrongMigrations::Migration)
