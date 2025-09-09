module StrongMigrations
  class MigrationChecker
    PRIMARY_DATABASE = "primary"
    TEST_DATABASE = "test"

    def initialize
      @failed_migrations = []
      @checked_count = 0
    end

    def run
      target_databases.each { |database| check_database(database) }
      report_results
    end

    private

    def target_databases
      return [PRIMARY_DATABASE] unless rails_application?
      configured_databases.reject { |database| skip_database?(database) }
    end

    def configured_databases
      Rails.application.config.database_configuration.keys
    end

    def skip_database?(database)
      database == TEST_DATABASE || StrongMigrations.skipped_databases.include?(database)
    end

    def rails_application?
      defined?(Rails) && Rails.respond_to?(:application) && Rails.application
    end

    def check_database(database)
      connection_pool = connection_pool_for(database)
      return unless connection_pool

      pending_migrations = find_pending_migrations(connection_pool)
      return if pending_migrations.empty?

      process_migrations(pending_migrations, connection_pool)
    end

    def connection_pool_for(database)
      if database == PRIMARY_DATABASE
        ActiveRecord::Base.connection_pool
      else
        ActiveRecord::Base.connection_handler.retrieve_connection_pool(database)
      end
    end

    def find_pending_migrations(connection_pool)
      migration_context = connection_pool.migration_context
      applied_versions = migration_context.get_all_versions

      migration_context.migrations.reject do |migration|
        applied_versions.include?(migration.version)
      end
    end

    def process_migrations(migrations, connection_pool)
      migrations.each do |migration|
        check_migration(migration, connection_pool)
      end
      @checked_count += migrations.size
    end

    def check_migration(migration, connection_pool)
      connection_pool.with_connection do |connection|
        test_migration(migration, connection)
      end
    rescue StrongMigrations::Error => e
      record_failure(migration, e.message)
    end

    def test_migration(migration, connection)
      connection.transaction(requires_new: true) do
        migration_instance = migration.send(:migration)
        migration_instance.migrate(:up)
        raise ActiveRecord::Rollback
      end
    end

    def record_failure(migration, error_message)
      @failed_migrations << {
        version: migration.version,
        name: migration.name,
        error: error_message
      }
    end

    def report_results
      return output_no_migrations if @checked_count == 0
      return output_failures if @failed_migrations.any?
      
      output_success
    end

    def output_no_migrations
      puts "No pending migrations found to check"
      exit 0
    end

    def output_failures
      puts "Strong Migrations found issues with #{@failed_migrations.size} of #{@checked_count} pending migrations:\n\n"
      
      @failed_migrations.each do |migration|
        puts "#{migration[:version]}_#{migration[:name]}"
        puts "   #{migration[:error]}\n\n"
      end
      
      puts "Run `bundle exec rails g strong_migrations:install` to configure."
      exit 1
    end

    def output_success
      puts "All #{@checked_count} pending migrations are compliant!"
      exit 0
    end
  end
end
