require "active_record"
require "strong_migrations/version"
require "strong_migrations/unsafe_migration"
require "strong_migrations/migration"
require "strong_migrations/railtie" if defined?(Rails)

module StrongMigrations
  class << self
    attr_accessor :auto_analyze
  end
  self.auto_analyze = false
end

ActiveRecord::Migration.send(:prepend, StrongMigrations::Migration)
