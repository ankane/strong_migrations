require_relative "test_helper"

class SQLiteTest < Minitest::Test
  class AnimalsRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  def setup
    skip unless $adapter == "sqlite3"
    super
    @checker = StrongMigrations::Checker.new(TestMigration.new)
    @adapter = @checker.send(:adapter)
  end

  def test_connection_and_schema
    connection = ActiveRecord::Base.connection
    assert_equal "SQLite", connection.adapter_name
    assert_equal ":memory:", ActiveRecord::Base.connection_db_config.database
    assert connection.table_exists?(:users)
    assert connection.table_exists?(:orders)
    assert connection.table_exists?(:devices)
    assert connection.column_exists?(:users, :order_id)
  end

  def test_migration_round_trip
    assert_output(nil, "") do
      migrate CreateJoinTable
      assert ActiveRecord::Base.connection.table_exists?(:cities_users)
      migrate CreateJoinTable, direction: :down
      refute ActiveRecord::Base.connection.table_exists?(:cities_users)
    end
  end

  def test_adapter
    assert_instance_of StrongMigrations::Adapters::SQLiteAdapter, @adapter
    assert_equal "SQLite", @adapter.name
    version = ActiveRecord::Base.connection.select_value("SELECT sqlite_version()")
    assert_equal Gem::Version.new(version), @adapter.server_version
  end

  def test_target_version
    with_target_version("3.23.0") do
      assert_equal Gem::Version.new("3.23.0"), @adapter.server_version
    end
  end

  def test_target_version_per_database
    config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
      "test", "animals", adapter: "sqlite3", database: ":memory:"
    )
    AnimalsRecord.establish_connection(config)
    @checker.define_singleton_method(:connection) { AnimalsRecord.connection }
    with_target_version(primary: "3.23.0", animals: "3.24.0") do
      assert_equal Gem::Version.new("3.24.0"), @adapter.server_version
    end
  ensure
    AnimalsRecord.remove_connection
  end

  def test_target_version_unconfigured
    error = assert_raises(StrongMigrations::Error) do
      with_target_version(animals: "3.23.0") do
        @adapter.server_version
      end
    end
    assert_equal "StrongMigrations.target_version is not configured for :primary database", error.message
  end

  def test_target_version_outside_developer_env
    outside_developer_env do
      with_target_version(1) do
        version = ActiveRecord::Base.connection.select_value("SELECT sqlite_version()")
        assert_equal Gem::Version.new(version), @adapter.server_version
      end
    end
  end

  def test_unsupported_version
    error = assert_raises(StrongMigrations::UnsupportedVersion) do
      with_target_version("3.7.0") do
        migrate CreateJoinTable
      end
    end
    assert_match "SQLite version (3.7.0) not supported", error.message
    refute ActiveRecord::Base.connection.table_exists?(:cities_users)
  end

  def test_application_compatibility_checks
    assert_unsafe RemoveColumn, "ignored_columns"
    assert_unsafe RenameColumn, "Renaming a column"
    assert_unsafe RenameTable, "Renaming a table"
    assert_unsafe CreateTableForce
    assert ActiveRecord::Base.connection.column_exists?(:users, :name)
    refute ActiveRecord::Base.connection.table_exists?(:admins)
  end

  def test_default
    assert_metadata_only_addition AddColumnDefault, 1
  end

  def test_default_false
    assert_metadata_only_addition AddColumnDefaultFalse, 0
  end

  def test_default_null
    assert_metadata_only_addition AddColumnDefaultNull, nil
  end

  def test_literal_that_looks_like_an_expression
    assert_metadata_only_addition AddColumnDefaultLiteral, "CURRENT_TIMESTAMP"
  end

  def test_default_not_null
    assert_metadata_only_addition AddColumnDefaultNotNullLiteral, 0
  end

  def test_generated_virtual
    assert_metadata_only_addition AddColumnGeneratedVirtual, "amsterdam"
  end

  def test_not_null_without_default
    assert_column_rejected AddColumnNotNull, "rebuild"
  end

  def test_primary_key
    assert_column_rejected AddColumnPrimaryKey, "rebuild"
  end

  def test_primary_key_option
    assert_column_rejected AddColumnPrimaryKeyOption, "rebuild"
  end

  def test_generated_stored
    assert_column_rejected AddColumnGeneratedStored, "rebuild"
  end

  def test_generated_not_null
    assert_column_rejected AddColumnGeneratedNotNull, "rebuild"
  end

  def test_generated_stored_native_type
    assert_column_rejected AddColumnGeneratedStoredNativeType, "rebuild or scan"
  end

  def test_custom_sql_type
    assert_column_rejected AddColumnSqlCheck, "rebuild or scan"
  end

  def test_generated_custom_sql_type
    assert_column_rejected AddColumnGeneratedSqlCheck, "rebuild or scan"
  end

  def test_callable_default
    assert_column_rejected AddColumnDefaultCallableNow, "expression default"
  end

  def test_callable_literal_default
    assert_column_rejected AddColumnDefaultCallableLiteral, "expression default"
  end

  def test_safety_assured
    User.create!(city: "Amsterdam")
    with_safety_assured do
      statements = capture_statements { migrate AddColumnGeneratedStored }
      assert statements.any? { |sql| sql.match?(/\AINSERT INTO "a?users".*SELECT/m) }
      assert ActiveRecord::Base.connection.column_exists?(:users, :nice)
      assert_equal [["Amsterdam", "amsterdam"]], ActiveRecord::Base.connection.select_rows("SELECT city, nice FROM users")
      migrate AddColumnGeneratedStored, direction: :down
    end
    refute ActiveRecord::Base.connection.column_exists?(:users, :nice)
  ensure
    migrate AddColumnGeneratedStored, direction: :down if ActiveRecord::Base.connection.column_exists?(:users, :nice)
    User.delete_all
  end

  def test_disabled_default_check
    with_option(:enabled_checks, StrongMigrations.enabled_checks.except(:add_column_default_sqlite)) do
      migrate AddColumnDefaultCallableLiteral
      assert ActiveRecord::Base.connection.column_exists?(:users, :nice)
      migrate AddColumnDefaultCallableLiteral, direction: :down
    end
    refute ActiveRecord::Base.connection.column_exists?(:users, :nice)
  end

  def test_disabled_rebuild_check
    with_option(:enabled_checks, StrongMigrations.enabled_checks.except(:add_column_sqlite)) do
      migrate AddColumnNotNull
      refute ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "nice" }.null
      migrate AddColumnNotNull, direction: :down
    end
    refute ActiveRecord::Base.connection.column_exists?(:users, :nice)
  end

  def test_disabled_rebuild_check_for_generated_columns
    with_option(:enabled_checks, StrongMigrations.enabled_checks.except(:add_column_sqlite)) do
      [{stored: true}, {null: false}].each do |options|
        options = options.merge(type: :string, as: "LOWER(city)")
        assert @checker.perform(:add_column, :users, :nice, :virtual, options) { true }
      end
    end
  end

  def test_disabled_rebuild_check_preserves_other_checks
    with_option(:enabled_checks, StrongMigrations.enabled_checks.except(:add_column_sqlite)) do
      error = assert_raises(StrongMigrations::UnsafeMigration) do
        @checker.perform(:add_column, :users, :nice, :integer, primary_key: true, default: -> { "1" }) { true }
      end
      assert_match "expression default", error.message

      error = assert_raises(StrongMigrations::UnsafeMigration) do
        @checker.perform(:add_column, :users, :nice, :virtual, type: "integer CHECK (nice > 0)", as: "1", stored: true) { true }
      end
      assert_match "rebuild or scan", error.message
    end
  end

  def test_safe_by_default
    with_option(:safe_by_default, true) do
      refute @checker.safe_by_default_method?(:change_column_null)
      with_safety_assured do
        migrate ChangeColumnNullDefault
        refute ActiveRecord::Base.connection.columns(:users).find { |c| c.name == "name" }.null
        migrate ChangeColumnNullDefault, direction: :down
        assert ActiveRecord::Base.connection.columns(:users).find { |c| c.name == "name" }.null
      end
    end
  end

  def test_change_column
    assert_column_change_rejected ChangeColumnVarcharToText
  end

  def test_change_column_same_type
    assert_column_change_rejected ChangeColumnSameType
  end

  def test_change_column_default
    with_partial_inserts(false) do
      assert_column_change_rejected ChangeColumnDefault
    end
  end

  def test_change_column_default_hash
    with_partial_inserts(false) do
      assert_column_change_rejected ChangeColumnDefaultHash
    end
  end

  def test_change_column_default_new_column
    statements = capture_statements { assert_unsafe ChangeColumnDefaultNewColumn, "rebuild" }
    writes = statements.grep(/\A(?:ALTER|CREATE|DROP|INSERT|UPDATE|DELETE)\b.*"a?users"/m)
    assert_equal 1, writes.size
    assert_match(/\AALTER TABLE "users" ADD "nice"/, writes.first)
    refute ActiveRecord::Base.connection.column_exists?(:users, :nice)
  end

  def test_change_column_null
    assert_column_change_rejected ChangeColumnNull
  end

  def test_change_column_allow_null
    with_safety_assured { migrate ChangeColumnNull }
    assert_column_change_rejected ChangeColumnAllowNull
  ensure
    migrate ChangeColumnNull, direction: :down
  end

  def test_change_column_null_default
    User.create!(name: nil)
    assert_column_change_rejected ChangeColumnNullDefault
  end

  def test_change_column_safe_by_default
    with_option(:safe_by_default, true) do
      assert_column_change_rejected ChangeColumnNullDefault
    end
  end

  def test_change_column_down
    with_safety_assured { migrate ChangeColumnDefaultHash }
    with_option(:check_down, true) do
      assert_column_change_rejected ChangeColumnDefaultHash, direction: :down
    end
  ensure
    migrate ChangeColumnDefaultHash, direction: :down
  end

  def test_change_column_safety_assured
    assert_column_change_rebuild(ChangeColumnVarcharToText, ["Existing"]) do
      assert_equal :text, ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "name" }.type
      assert_equal [["Existing"]], ActiveRecord::Base.connection.select_rows("SELECT name FROM users")
    end
  end

  def test_change_column_default_safety_assured
    assert_column_change_rebuild(ChangeColumnDefaultHash, ["Existing"]) do
      assert_equal "Test", ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "name" }.default
      assert_equal [["Existing"]], ActiveRecord::Base.connection.select_rows("SELECT name FROM users")
    end
  end

  def test_change_column_null_default_safety_assured
    assert_column_change_rebuild(ChangeColumnNullDefault, [nil, "Existing"]) do |statements|
      assert statements.any? { |sql| sql.start_with?('UPDATE "users"') }
      refute ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "name" }.null
      assert_equal [["Andy"], ["Existing"]], ActiveRecord::Base.connection.select_rows("SELECT name FROM users ORDER BY id")
    end
  end

  def test_disabled_change_column_check
    User.create!(name: "Existing")
    User.create!(name: nil)
    with_option(:enabled_checks, StrongMigrations.enabled_checks.except(:change_column_sqlite)) do
      with_partial_inserts(false) do
        migrate ChangeColumnVarcharToText
        migrate ChangeColumnDefaultHash
        migrate ChangeColumnNullDefault
      end
    end
    column = ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "name" }
    assert_equal :text, column.type
    assert_equal "Test", column.default
    refute column.null
    assert_equal [["Existing"], ["Andy"]], ActiveRecord::Base.connection.select_rows("SELECT name FROM users ORDER BY id")
  ensure
    with_safety_assured do
      migrate ChangeColumnNullDefault, direction: :down
      migrate ChangeColumnDefaultHash, direction: :down
      migrate ChangeColumnVarcharToText, direction: :down
    end
    User.delete_all
  end

  def test_disabled_change_column_check_preserves_partial_inserts_check
    with_option(:enabled_checks, StrongMigrations.enabled_checks.except(:change_column_sqlite)) do
      with_partial_inserts(true) do
        assert_column_change_rejected ChangeColumnDefaultHash, "partial_inserts"
      end
    end
  end

  def test_change_column_before_start_after
    with_start_after(123) do
      migrate ChangeColumnDefaultHash
      assert_equal "Test", ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "name" }.default
      migrate ChangeColumnDefaultHash, direction: :down
    end
    assert_nil ActiveRecord::Base.connection.columns(:users).find { |column| column.name == "name" }.default
  ensure
    with_safety_assured { migrate ChangeColumnDefaultHash, direction: :down }
  end

  def test_skipped_database
    with_option(:skipped_databases, ["primary"]) do
      with_target_version(1) do
        assert_safe CreateJoinTable
      end
    end
  end

  private

  def assert_column_change_rebuild(migration, names)
    names.each { |name| User.create!(name: name) }
    with_safety_assured do
      statements = capture_statements { migrate migration }
      assert statements.any? { |sql| sql.match?(/\AINSERT INTO "a?users".*SELECT/m) }
      yield statements
    end
  ensure
    with_safety_assured { migrate migration, direction: :down }
    User.delete_all
  end

  def assert_column_change_rejected(migration, message = "rebuild", **options)
    User.create!(name: "Existing")
    connection = ActiveRecord::Base.connection
    schema_sql = "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'users'"
    schema = connection.select_value(schema_sql)
    rows = connection.select_rows("SELECT * FROM users ORDER BY id")
    statements = capture_statements { assert_unsafe migration, message, **options }
    assert_empty statements.grep(/\A(?:ALTER|CREATE|DROP|INSERT|UPDATE|DELETE)\b.*"a?users"/m)
    assert_equal schema, connection.select_value(schema_sql)
    assert_equal rows, connection.select_rows("SELECT * FROM users ORDER BY id")
  ensure
    User.delete_all
  end

  def assert_metadata_only_addition(migration, value)
    User.create!(city: "Amsterdam")
    statements = capture_statements { migrate migration }
    table_statements = statements.grep(/\A(?:ALTER|CREATE|DROP|INSERT INTO).*"a?users"/)
    assert_equal 1, table_statements.size
    assert_match(/\AALTER TABLE "users" ADD "nice"/, table_statements.first)
    assert_equal [[value]], ActiveRecord::Base.connection.select_rows("SELECT nice FROM users")
  ensure
    migrate migration, direction: :down if ActiveRecord::Base.connection.column_exists?(:users, :nice)
    User.delete_all
  end

  def assert_column_rejected(migration, message)
    statements = capture_statements { assert_unsafe migration, message }
    refute statements.any? { |sql| sql.match?(/\A(?:ALTER|CREATE|DROP|INSERT INTO).*"a?users"/) }
    refute ActiveRecord::Base.connection.column_exists?(:users, :nice)
  ensure
    migrate migration, direction: :down if ActiveRecord::Base.connection.column_exists?(:users, :nice)
  end
end
