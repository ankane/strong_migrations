require_relative "test_helper"

class MigrationCheckerTest < Minitest::Test
  def setup
    @checker = StrongMigrations::MigrationChecker.new
  end

  def test_database_filtering_logic
    rails_app = create_rails_app(["development", "test", "production"])
    
    Rails.stub(:respond_to?, ->(method) { method == :application }) do
      Rails.stub(:application, rails_app) do
        StrongMigrations.stub(:skipped_databases, ["production"]) do
          databases = @checker.send(:target_databases)
          
          assert_equal ["development"], databases
          refute_includes databases, "test"
          refute_includes databases, "production"
        end
      end
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
    config = create_mock_object(database_configuration: databases.to_h { |db| [db, {}] })
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

end