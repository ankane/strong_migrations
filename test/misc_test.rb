require_relative "test_helper"

class MiscTest < Minitest::Test
  def test_execute_arbitrary_sql
    assert_unsafe ExecuteArbitrarySQL
  end

  def test_rename_column
    assert_unsafe RenameColumn
  end

  def test_rename_table
    assert_unsafe RenameTable
  end

  def test_create_table_force
    assert_unsafe CreateTableForce
  end

  def test_create_join_table
    assert_safe CreateJoinTable
  end

  def test_create_join_table_force
    assert_unsafe CreateJoinTableForce
  end

  def test_custom
    assert_unsafe Custom, "Cannot add forbidden column"
  end

  def test_unsupported_version
    error = assert_raises(StrongMigrations::UnsupportedVersion) do
      with_target_version(1) do
        migrate ExecuteArbitrarySQL
      end
    end
    assert_match "version (1) not supported", error.message
  end

  def test_target_version_outside_developer_env
    outside_developer_env do
      with_target_version(1) do
        # ignores target version
        # (does not throw UnsupportedVersion error)
        assert_unsafe ExecuteArbitrarySQL
      end
    end
  end

  def test_target_version_multiple_dbs_below_6_1
    skip if multiple_dbs?

    with_target_version({ primary: 10, animals: 15.0 }) do
      error = assert_raises(StrongMigrations::Error) do
        assert_safe AddColumnDefault
      end
      assert_equal "StrongMigrations.target_version does not support multiple databases for ActiveRecord < 6.1", error.message
    end
  end

  def test_target_version_multiple_dbs
    skip unless multiple_dbs?

    with_multiple_dbs do

      safe_version = postgresql? ? 11 : (mysql? ? "8.0.12" : "10.3.2")
      with_target_version({ primary: safe_version }) do
        assert_safe AddColumnDefault
      end

      unsafe_version = postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")
      with_target_version({ primary: unsafe_version }) do
        assert_unsafe AddColumnDefault
      end
    end
  end

  def test_target_version_multiple_dbs_unconfigured
    skip unless multiple_dbs?

    with_multiple_dbs do
      error = assert_raises(StrongMigrations::Error) do
        with_target_version({ animals: 10 }) do
          assert_safe AddColumnDefault
        end
      end
      assert_equal "StrongMigrations.target_version is not configured for :primary", error.message
    end
  end

  private

  def with_multiple_dbs(&block)
    previous_db_config =
      if ar_version >= 6.1
        ActiveRecord::Base.connection_db_config.configuration_hash
      else
        ActiveRecord::Base.connection_config
      end

    multi_db_config = {
      "test" => {
        "primary" => {
          "adapter" => $adapter,
          "database" => "strong_migrations_test"
        },
        "animals" => {
          "adapter" => $adapter,
          "database" => "animals_test"
        }
      }
    }
    ActiveRecord::Base.configurations = multi_db_config

    ActiveRecord::Base.connects_to(database: { writing: :primary })
    ActiveRecord::Base.connected_to(role: :writing, &block)
  ensure
    ActiveRecord::Base.establish_connection(previous_db_config)
  end

  def multiple_dbs?
    ar_version >= 6.1
  end

  def ar_version
    ActiveRecord::VERSION::STRING.to_f
  end
end
