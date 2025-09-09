require_relative "test_helper"

class MigrationCheckerTest < Minitest::Test
  def setup
    @checker = StrongMigrations::MigrationChecker.new
  end

  def test_target_databases_filters_test_and_skipped
    dev_pool = create_connection_pool_with_name("development")
    test_pool = create_connection_pool_with_name("test")
    prod_pool = create_connection_pool_with_name("production")
    
    Rails.stub(:respond_to?, ->(method) { method == :application }) do
      Rails.stub(:application, Object.new) do
        ActiveRecord::Base.connection_handler.stub(:connection_pool_list, [dev_pool, test_pool, prod_pool]) do
          StrongMigrations.stub(:skipped_databases, ["production"]) do
            pools = @checker.send(:target_databases)
            
            assert_equal 1, pools.size
            assert_equal "development", pools.first.db_config.name
          end
        end
      end
    end
  end


  def test_target_databases_returns_default_when_not_rails_app
    Rails.stub(:respond_to?, false) do
      pools = @checker.send(:target_databases)
      
      assert_equal 1, pools.size
      assert_equal ActiveRecord::Base.connection_pool, pools.first
    end
  end

  def test_skip_database_filters_test_and_configured_skipped
    assert @checker.send(:skip_database?, "test")
    
    with_skip_database("production") do
      assert @checker.send(:skip_database?, "production")
      refute @checker.send(:skip_database?, "development")
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

  def create_connection_pool_with_name(db_name)
    db_config = create_mock_object(name: db_name)
    create_mock_object(db_config: db_config)
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

  def with_skip_database(database)
    StrongMigrations.stub(:skipped_databases, [database]) do
      yield
    end
  end

end