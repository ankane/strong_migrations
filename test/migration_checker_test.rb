require_relative "test_helper"

class MigrationCheckerTest < Minitest::Test
  def setup
    @checker = StrongMigrations::MigrationChecker.new
  end

  def test_target_databases_filters_test_and_skipped
    with_rails_app(["development", "test", "production"]) do
      StrongMigrations.stub(:skipped_databases, ["production"]) do
        databases = @checker.send(:target_databases)
        
        assert_equal ["development"], databases
        refute_includes databases, "test"
        refute_includes databases, "production"
      end
    end
  end

  def test_primary_database_name_prefers_primary
    with_rails_app(["primary", "secondary"]) do
      assert_equal "primary", @checker.send(:primary_database_name)
    end
  end

  def test_primary_database_name_uses_rails_env
    with_rails_app(["development", "staging"]) do
      Rails.stub(:env, "development") do
        assert_equal "development", @checker.send(:primary_database_name)
      end
    end
  end

  def test_primary_database_name_falls_back_to_default
    with_rails_app(["default", "backup"]) do
      assert_equal "default", @checker.send(:primary_database_name)
    end
  end

  def test_primary_database_name_without_rails
    Rails.stub(:respond_to?, false) do
      assert_equal "default", @checker.send(:primary_database_name)
    end
  end

  def test_rails_application_detection
    Rails.stub(:respond_to?, false) do
      refute @checker.send(:rails_application?)
    end
    
    Rails.stub(:respond_to?, true) do
      Rails.stub(:application, nil) do
        refute @checker.send(:rails_application?)
      end
    end
  end

  def test_pending_migration_detection
    migration1 = create_mock_migration(123, "Applied")
    migration2 = create_mock_migration(456, "Pending")
    connection_pool = create_connection_pool([migration1, migration2], [123])
    
    pending = @checker.send(:find_pending_migrations, connection_pool)
    
    assert_equal 1, pending.size
    assert_equal 456, pending.first.version
    assert_equal "Pending", pending.first.name
  end

  private

  def create_mock_migration(version, name)
    create_mock_object(
      version: version,
      name: name,
      filename: "db/migrate/#{version}_#{name.underscore}.rb"
    )
  end

  def create_rails_app(databases)
    # Ensure keys are returned in the order we specify
    database_config = {}
    databases.each { |db| database_config[db] = {} }
    config = create_mock_object(database_configuration: database_config)
    create_mock_object(config: config)
  end

  def create_connection_pool(migrations, applied_versions)
    migration_context = create_mock_object(
      migrations: migrations,
      get_all_versions: applied_versions
    )
    create_mock_object(migration_context: migration_context)
  end

  def create_mock_object(**methods)
    mock = Object.new
    methods.each { |method, value| mock.define_singleton_method(method) { value } }
    mock
  end

  def with_rails_app(databases)
    rails_app = create_rails_app(databases)
    Rails.stub(:respond_to?, ->(method) { method == :application }) do
      Rails.stub(:application, rails_app) do
        yield
      end
    end
  end

end