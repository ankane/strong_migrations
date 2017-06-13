require "active_record"
require "strong_migrations/version"
require "strong_migrations/unsafe_migration"
require "strong_migrations/migration"
require "strong_migrations/railtie" if defined?(Rails)

module StrongMigrations
  class << self
    attr_accessor :auto_analyze
    attr_accessor :assume_safety_prior_to_version
  end

  self.auto_analyze = false
  self.assume_safety_prior_to_version = 0
end

ActiveRecord::Migration.send(:prepend, StrongMigrations::Migration)
