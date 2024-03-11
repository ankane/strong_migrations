require_relative "test_helper"

class AddColumnTest < Minitest::Test
  def test_default
    if mysql? || mariadb?
      assert_safe AddColumnDefault
    else
      with_target_version(10) do
        assert_unsafe AddColumnDefault
      end
    end
  end

  def test_default_database_specific_versions
    skip unless postgresql?
    StrongMigrations.target_postgresql_version = "10"
    assert_unsafe AddColumnDefault
  ensure
    StrongMigrations.target_postgresql_version = nil
  end

  def test_default_null
    skip unless postgresql?

    with_target_version(10) do
      assert_unsafe AddColumnDefaultNull, "Adding a column with a null default"
    end
  end

  def test_default_not_null
    skip unless postgresql?

    with_target_version(10) do
      assert_unsafe AddColumnDefaultNotNull, "Then add the NOT NULL constraint"
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

  def test_generated_stored
    assert_unsafe AddColumnGeneratedStored
  end

  def test_generated_virtual
    skip if postgresql?
    assert_safe AddColumnGeneratedVirtual
  end

  def test_primary_key
    if mysql? || mariadb?
      assert_unsafe AddColumnPrimaryKey, "statement-based replication"
    else
      assert_unsafe AddColumnPrimaryKey
    end
  end

  def test_serial
    skip unless postgresql?
    assert_unsafe AddColumnSerial
  end

  def test_bigserial
    skip unless postgresql?
    assert_unsafe AddColumnBigserial
  end
end
