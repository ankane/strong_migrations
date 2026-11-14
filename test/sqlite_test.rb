require_relative "test_helper"

class SQLiteTest < Minitest::Test
  def setup
    skip unless $adapter == "sqlite3"
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
    assert_output(nil, /Unsupported adapter: SQLite/) do
      migrate CreateJoinTable
      assert ActiveRecord::Base.connection.table_exists?(:cities_users)
      migrate CreateJoinTable, direction: :down
      refute ActiveRecord::Base.connection.table_exists?(:cities_users)
    end
  end
end
