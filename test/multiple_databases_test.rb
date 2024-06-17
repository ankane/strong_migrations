require_relative "test_helper"

class MultipleDatabasesTest < Minitest::Test
  def test_target_version
    skip unless postgresql?

    with_target_version({primary: 12, animals: 16}) do
      with_database(:primary) do
        # TODO use new check
        # assert_unsafe AddColumnDefault
      end
      with_database(:animals) do
        assert_safe AddColumnDefault
      end
    end
  end

  def test_target_version_unconfigured
    error = assert_raises(StrongMigrations::Error) do
      with_target_version({primary: 12}) do
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
end
