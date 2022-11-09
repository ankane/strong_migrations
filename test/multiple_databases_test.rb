require_relative "test_helper"

class MultipleDatabasesTest < Minitest::Test
  def test_unsupported
    skip if multiple_dbs?

    with_target_version({primary: 10, animals: 15}) do
      error = assert_raises(StrongMigrations::Error) do
        assert_safe AddColumnDefault
      end
      assert_equal "StrongMigrations.target_version does not support multiple databases for Active Record < 6.1", error.message
    end
  end

  def test_target_version
    skip unless multiple_dbs?

    safe_version = postgresql? ? 11 : (mysql? ? "8.0.12" : "10.3.2")
    unsafe_version = postgresql? ? 10 : (mysql? ? "8.0.11" : "10.3.1")
    with_target_version({primary: unsafe_version, animals: safe_version}) do
      with_database(:primary) do
        assert_unsafe AddColumnDefault
      end
      with_database(:animals) do
        assert_safe AddColumnDefault
      end
    end
  end

  def test_target_version_unconfigured
    skip unless multiple_dbs?

    error = assert_raises(StrongMigrations::Error) do
      with_target_version({primary: 10}) do
        with_database(:animals) do
          assert_safe AddColumnDefault
        end
      end
    end
    assert_equal "StrongMigrations.target_version is not configured for :animals database", error.message
  end

  private

  def with_database(database, &block)
    previous_configurations = ActiveRecord::Base.configurations
    previous_db_config = ActiveRecord::Base.connection_db_config.configuration_hash

    ActiveRecord::Base.configurations = {
      "test" => {
        "primary" => previous_db_config,
        "animals" => previous_db_config
      }
    }
    ActiveRecord::Base.establish_connection(database)
    yield
  ensure
    ActiveRecord::Base.configurations = previous_configurations if previous_configurations
    ActiveRecord::Base.establish_connection(previous_db_config) if previous_db_config
  end

  def multiple_dbs?
    ActiveRecord::VERSION::STRING.to_f >= 6.1
  end
end
