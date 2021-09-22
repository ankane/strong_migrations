require_relative "test_helper"

class AddColumnDefaultTest < Minitest::Test
  def test_add_column_default_without_enabled_tables
    without_enabled_tables do
      assert_safe AddColumnDefault
    end
  end

  def test_add_column_default
    with_target_version(postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")) do
      assert_unsafe AddColumnDefault
    end
  end

  def test_add_column_default_database_specific_versions
    StrongMigrations.target_postgresql_version = "10"
    StrongMigrations.target_mysql_version = "8.0.11"
    StrongMigrations.target_mariadb_version = "10.3.1"
    assert_unsafe AddColumnDefault
  ensure
    StrongMigrations.target_postgresql_version = nil
    StrongMigrations.target_mysql_version = nil
    StrongMigrations.target_mariadb_version = nil
  end

  def test_add_column_default_not_null
    with_target_version(postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")) do
      assert_unsafe AddColumnDefaultNotNull, /Then add the NOT NULL constraint/
    end
  end

  def test_add_column_default_safe_latest
    skip unless postgresql? || mysql? || mariadb?

    with_target_version(postgresql? ? 11 : (mysql? ? "8.0.12" : "10.3.2")) do
      assert_safe AddColumnDefault
    end
  end

  def test_add_column_default_safe
    assert_safe AddColumnDefaultSafe
  end
end
