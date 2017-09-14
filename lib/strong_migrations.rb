require "active_record"
require "strong_migrations/version"
require "strong_migrations/unsafe_migration"
require "strong_migrations/migration"
require "strong_migrations/railtie" if defined?(Rails)

module StrongMigrations
  class << self
    attr_accessor :auto_analyze, :start_after, :error_messages
  end
  self.auto_analyze = false
  self.start_after = 0
  self.error_messages = {
    remove_column:      StrongMigrations::UnsafeMigration::Messages::RemoveColumn,
    change_table:       StrongMigrations::UnsafeMigration::Messages::ChangeTable,
    rename_table:       StrongMigrations::UnsafeMigration::Messages::RenameTable,
    rename_column:      StrongMigrations::UnsafeMigration::Messages::RenameColumn,
    add_index_columns:  StrongMigrations::UnsafeMigration::Messages::AddIndexColumns,
    add_index:          StrongMigrations::UnsafeMigration::Messages::AddIndex,
    add_column_default: StrongMigrations::UnsafeMigration::Messages::AddColumnDefault,
    add_column_json:    StrongMigrations::UnsafeMigration::Messages::AddColumnJson,
    change_column:      StrongMigrations::UnsafeMigration::Messages::ChangeColumn,
    create_table:       StrongMigrations::UnsafeMigration::Messages::CreateTable,
    add_reference:      StrongMigrations::UnsafeMigration::Messages::AddReference,
    execute:            StrongMigrations::UnsafeMigration::Messages::Execute
  }
end

ActiveRecord::Migration.send(:prepend, StrongMigrations::Migration)
