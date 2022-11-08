require_relative "test_helper"

class MultipleDatabasesTest < Minitest::Test
  def test_unsupported
    skip if multiple_dbs?

    with_target_version({primary: 10, animals: 15}) do
      error = assert_raises(StrongMigrations::Error) do
        assert_safe AddColumnDefault
      end
      assert_equal "StrongMigrations.target_version does not support multiple databases for ActiveRecord < 6.1", error.message
    end
  end

  def test_target_version
    skip unless multiple_dbs?

    with_multiple_dbs do
      safe_version = postgresql? ? 11 : (mysql? ? "8.0.12" : "10.3.2")
      with_target_version({primary: safe_version}) do
        assert_safe AddColumnDefault
      end

      unsafe_version = postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")
      with_target_version({primary: unsafe_version}) do
        assert_unsafe AddColumnDefault
      end
    end
  end

  def test_target_version_unconfigured
    skip unless multiple_dbs?

    with_multiple_dbs do
      error = assert_raises(StrongMigrations::Error) do
        with_target_version({animals: 10}) do
          assert_safe AddColumnDefault
        end
      end
      assert_equal "StrongMigrations.target_version is not configured for :primary", error.message
    end
  end

  private

  def with_multiple_dbs(&block)
    previous_db_config = ActiveRecord::Base.connection_db_config.configuration_hash

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
    ActiveRecord::Base.connects_to(database: {writing: :primary})
    yield
  ensure
    ActiveRecord::Base.establish_connection(previous_db_config)
  end

  def multiple_dbs?
    ActiveRecord::VERSION::STRING.to_f >= 6.1
  end
end
