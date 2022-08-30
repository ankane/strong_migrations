require_relative "test_helper"

class AddColumnTest < Minitest::Test
  def test_default
    with_target_version(postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")) do
      assert_unsafe AddColumnDefault
    end
  end

  def test_default_database_specific_versions
    StrongMigrations.target_postgresql_version = "10"
    StrongMigrations.target_mysql_version = "8.0.11"
    StrongMigrations.target_mariadb_version = "10.3.1"
    assert_unsafe AddColumnDefault
  ensure
    StrongMigrations.target_postgresql_version = nil
    StrongMigrations.target_mysql_version = nil
    StrongMigrations.target_mariadb_version = nil
  end

  def test_default_not_null
    with_target_version(postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")) do
      assert_unsafe AddColumnDefaultNotNull, /Then add the NOT NULL constraint/
    end
  end

  def test_default_safe_latest
    skip unless postgresql? || mysql? || mariadb?

    with_target_version(postgresql? ? 11 : (mysql? ? "8.0.12" : "10.3.2")) do
      assert_safe AddColumnDefault
    end
  end

  def test_default_safe
    assert_safe AddColumnDefaultSafe
  end

  def test_default_callable
    # TODO check MySQL and MariaDB
    skip unless postgresql?
    assert_unsafe AddColumnDefaultCallable
  end

  def test_default_uuid
    skip unless postgresql?
    assert_unsafe AddColumnDefaultUUID
  end

  def test_json
    skip unless postgresql?
    assert_unsafe AddColumnJson
  end
end
