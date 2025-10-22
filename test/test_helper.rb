require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"

require_relative "support/active_record"
require_relative "support/helpers"

class Minitest::Test
  include Helpers

  def migrate(migration, direction: :up, version: 123)
    schema_migration.delete_all_versions
    migration = migration.new unless migration.is_a?(TestMigration)
    migration.version ||= version
    if direction == :down
      schema_migration.create_version(migration.version)
    end
    args = [schema_migration, connection_class.internal_metadata]
    ActiveRecord::Migrator.new(direction, [migration], *args).migrate
    true
  rescue => e
    raise e.cause || e
  end

  def assert_unsafe(migration, message = nil, **options)
    error = assert_raises(StrongMigrations::UnsafeMigration) do
      migrate(migration, **options)
    end
    puts error.message if ENV["VERBOSE"]
    assert_match message, error.message if message
  end

  def assert_safe(migration, direction: nil, **options)
    if direction
      assert migrate(migration, direction: direction, **options)
    else
      assert migrate(migration, direction: :up, **options)
      assert migrate(migration, direction: :down, **options)
    end
  end

  def assert_argument_error(migration)
    assert_raises(ArgumentError) do
      migrate(migration)
    end
  end

  def with_start_after(start_after)
    StrongMigrations.stub(:start_after, start_after) do
      yield
    end
  end

  def with_target_version(version)
    StrongMigrations.target_version = version
    yield
  ensure
    StrongMigrations.target_version = nil
  end

  def with_auto_analyze
    StrongMigrations.auto_analyze = true
    yield
  ensure
    StrongMigrations.auto_analyze = false
  end

  def with_safety_assured
    StrongMigrations::Checker.stub(:safe, true) do
      yield
    end
  end

  def outside_developer_env
    StrongMigrations.stub(:developer_env?, false) do
      yield
    end
  end

  def with_lock_timeout(lock_timeout)
    StrongMigrations.lock_timeout = lock_timeout
    yield
  ensure
    StrongMigrations.lock_timeout = nil
    ActiveRecord::Base.connection.execute("RESET lock_timeout")
  end

  def with_locked_table(table)
    pool = ActiveRecord::Base.connection_pool
    connection = pool.checkout

    if postgresql?
      connection.transaction do
        connection.execute("LOCK TABLE #{connection.quote_table_name(table)} IN ROW EXCLUSIVE MODE")
        yield
      end
    else
      begin
        connection.execute("LOCK TABLE #{connection.quote_table_name(table)} WRITE")
        yield
      ensure
        connection.execute("UNLOCK TABLES")
      end
    end
  ensure
    pool.checkin(connection) if connection
  end

  def assert_analyzed(migration)
    assert analyzed?(migration)
  end

  def refute_analyzed(migration)
    refute analyzed?(migration)
  end

  def analyzed?(migration)
    statements = capture_statements do
      migrate migration, direction: :up
    end
    migrate migration, direction: :down
    statements.any? { |s| s.start_with?("ANALYZE") }
  end

  def capture_statements
    statements = []
    callback = lambda do |_, _, _, _, payload|
      statements << payload[:sql] if payload[:name] != "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    statements
  end
end

StrongMigrations.add_check do |method, args|
  if method == :add_column && args[1].to_s == "forbidden"
    stop! "Cannot add forbidden column"
  end
end

Dir.glob("migrations/*.rb", base: __dir__).sort.each do |file|
  require_relative file
end
