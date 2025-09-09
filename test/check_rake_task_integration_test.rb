require_relative "test_helper"

class CheckTaskIntegrationTest < Minitest::Test
  def setup
    require "rake"
    
    @rake = Rake::Application.new
    Rake.application = @rake
    
    @rake.define_task(Rake::Task, "strong_migrations:check") do
      StrongMigrations.check_pending_migrations
    end
  end

  def teardown
    Rake.application = nil
  end

  def test_task_exists
    task_names = @rake.tasks.map(&:name)
    assert_includes task_names, "strong_migrations:check"
  end

  def test_no_pending_migrations
    migration_context = ActiveRecord::Base.connection_pool.migration_context
    migration_context.stub(:migrations, []) do
      output, exit_code = capture_output_and_exit do
        @rake["strong_migrations:check"].invoke
      end
      
      assert_match "No pending migrations found to check", output
      assert_equal 0, exit_code
    end
  end

  private

  def capture_output_and_exit
    require "stringio"
    
    old_stdout = $stdout
    $stdout = StringIO.new
    exit_code = nil
    
    begin
      yield
      exit_code = 0
    rescue SystemExit => e
      exit_code = e.status
    end
    
    [$stdout.string, exit_code]
  ensure
    $stdout = old_stdout
  end

end
