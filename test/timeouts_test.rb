require_relative "test_helper"

class TimeoutsTest < Minitest::Test
  def teardown
    reset_timeouts
  end

  def test_timeouts
    skip unless postgresql? || mysql? || mariadb?

    StrongMigrations.statement_timeout = 1.hour
    StrongMigrations.transaction_timeout = 2.hours
    StrongMigrations.lock_timeout = 10.seconds

    migrate CheckTimeouts

    if postgresql?
      assert_equal "1h", $statement_timeout
      assert_equal "2h", $transaction_timeout if transaction_timeout?
      assert_equal "10s", $lock_timeout
    else
      assert_equal 3600, $statement_timeout
      assert_equal 10, $lock_timeout
    end
  end

  def test_statement_timeout_float
    skip unless postgresql? || mysql? || mariadb?

    StrongMigrations.statement_timeout = 0.5.seconds

    migrate CheckTimeouts

    if postgresql?
      assert_equal "500ms", $statement_timeout
    else
      assert_equal 0.5, $statement_timeout
    end
  end

  # designed for 0 case to prevent no timeout
  # but can't test without statement timeout error
  def test_statement_timeout_float_ceil
    skip unless postgresql? || mysql?

    StrongMigrations.statement_timeout = 1.000001.seconds

    migrate CheckTimeouts

    if postgresql?
      assert_equal "1001ms", $statement_timeout
    else
      assert_equal 1.001, $statement_timeout
    end
  end

  def test_transaction_timeout_float
    skip unless transaction_timeout?

    StrongMigrations.transaction_timeout = 0.5.seconds

    migrate CheckTimeouts

    assert_equal "500ms", $transaction_timeout
  end

  # designed for 0 case to prevent no timeout
  # but can't test without transaction timeout error
  def test_transaction_timeout_float_ceil
    skip unless transaction_timeout?

    StrongMigrations.transaction_timeout = 1.000001.seconds

    migrate CheckTimeouts

    assert_equal "1001ms", $transaction_timeout
  end

  def test_transaction_timeout_is_set_before_statements
    skip unless transaction_timeout?

    StrongMigrations.transaction_timeout = 1.seconds

    migrate CheckTransactionTimeoutWithoutStatement

    assert_equal "1s", $transaction_timeout
  end

  def test_lock_timeout_float
    skip unless postgresql?

    StrongMigrations.lock_timeout = 0.5.seconds

    migrate CheckTimeouts

    assert_equal "500ms", $lock_timeout
  end

  def test_timeouts_string
    skip unless postgresql?

    StrongMigrations.statement_timeout = "1h"
    StrongMigrations.transaction_timeout = "2h"
    StrongMigrations.lock_timeout = "1d"

    migrate CheckTimeouts

    assert_equal "1h", $statement_timeout
    assert_equal "2h", $transaction_timeout if transaction_timeout?
    assert_equal "1d", $lock_timeout
  end

  def test_lock_timeout_limit
    StrongMigrations.lock_timeout_limit = 10.seconds
    StrongMigrations.lock_timeout = 20.seconds

    assert_output(nil, /Lock timeout is longer than 10 seconds/) do
      migrate CheckLockTimeout
    end
  ensure
    StrongMigrations.lock_timeout_limit = nil
  end

  def test_lock_timeout_limit_postgresql
    skip unless postgresql?

    StrongMigrations.lock_timeout_limit = 10.seconds

    # no warning
    ActiveRecord::Base.connection.execute("SET lock_timeout = '100ms'")
    _, stderr = capture_io do
      migrate CheckLockTimeout
    end
    refute_match(/Lock timeout is longer than 10 seconds/, stderr)

    # warning
    ["1min", "1h", "1d"].each do |timeout|
      ActiveRecord::Base.connection.execute("SET lock_timeout = '#{timeout}'")
      assert_output(nil, /Lock timeout is longer than 10 seconds/) do
        migrate CheckLockTimeout
      end
    end
  ensure
    StrongMigrations.lock_timeout_limit = nil
  end

  def test_lock_timeout_retries
    assert_retries CheckLockTimeoutRetries

    # MySQL and MariaDB do not support DDL transactions
    assert_equal (postgresql? ? 3 : 1), $migrate_attempts
  end

  def test_lock_timeout_retries_no_retries
    with_lock_timeout_retries(lock: false) do
      assert_safe CheckLockTimeoutRetries
      # up and down
      assert_equal 2, $migrate_attempts
    end
  end

  def test_lock_timeout_retries_transaction
    refute_retries CheckLockTimeoutRetriesTransaction

    # does not retry
    assert_equal 1, $migrate_attempts
    assert_equal 1, $transaction_attempts
  end

  def test_lock_timeout_retries_transaction_ddl_transaction
    skip "Requires DDL transaction" unless postgresql?

    assert_retries CheckLockTimeoutRetriesTransactionDdlTransaction

    # retries entire migration, not transaction block alone
    assert_equal 3, $migrate_attempts
    assert_equal 3, $transaction_attempts
  end

  def test_lock_timeout_retries_no_ddl_transaction
    assert_retries CheckLockTimeoutRetriesNoDdlTransaction

    # retries only single statement, not migration
    assert_equal 1, $migrate_attempts
  end

  def test_lock_timeout_retries_commit_db_transaction
    skip "Requires DDL transaction" unless postgresql?

    refute_retries CheckLockTimeoutRetriesCommitDbTransaction

    # does not retry since outside DDL transaction
    assert_equal 1, $migrate_attempts
  end

  def test_lock_timeout_retries_add_index
    skip unless postgresql?

    error = assert_raises(ActiveRecord::StatementInvalid) do
      with_lock_timeout_retries do
        migrate AddIndexConcurrently
      end
    end
    assert_kind_of PG::DuplicateTable, error.cause

    migrate AddIndexConcurrently, direction: :down
  end

  def test_lock_timeout_retries_add_index_remove_invalid_indexes
    skip unless postgresql?

    StrongMigrations.stub(:remove_invalid_indexes, true) do
      assert_retries AddIndexConcurrently
    end

    migrate AddIndexConcurrently, direction: :down
  end

  def reset_timeouts
    StrongMigrations.lock_timeout = nil
    StrongMigrations.transaction_timeout = nil
    StrongMigrations.statement_timeout = nil
    if postgresql?
      ActiveRecord::Base.connection.execute("RESET lock_timeout")
      ActiveRecord::Base.connection.execute("RESET transaction_timeout") if transaction_timeout?
      ActiveRecord::Base.connection.execute("RESET statement_timeout")
    elsif mysql?
      ActiveRecord::Base.connection.execute("SET max_execution_time = DEFAULT")
      ActiveRecord::Base.connection.execute("SET lock_wait_timeout = DEFAULT")
    elsif mariadb?
      ActiveRecord::Base.connection.execute("SET max_statement_time = DEFAULT")
      ActiveRecord::Base.connection.execute("SET lock_wait_timeout = DEFAULT")
    end
  end

  def with_lock_timeout_retries(lock: true)
    StrongMigrations.lock_timeout = postgresql? ? 0.1 : 1
    StrongMigrations.lock_timeout_retries = 2
    StrongMigrations.lock_timeout_retry_delay = 0
    $migrate_attempts = 0
    $transaction_attempts = 0

    if lock
      with_locked_table("users") do
        yield
      end
    else
      yield
    end
  ensure
    StrongMigrations.lock_timeout_retries = 0
    StrongMigrations.lock_timeout_retry_delay = 5
  end

  def assert_retries(migration, retries: 2, **options)
    retry_count = 0
    original_say = nil
    count = proc do |message, *args, **options|
      original_say.call(message, *args, **options)
      retry_count += 1 if message.include?("Lock timeout")
    end

    assert_raises(ActiveRecord::LockWaitTimeout) do
      with_lock_timeout_retries(**options) do
        migration = migration.new
        original_say = migration.method(:say)
        migration.stub(:say, count) do
          migrate migration
        end
      end
    end
    assert_equal retries, retry_count
  end

  def refute_retries(migration, **options)
    assert_retries(migration, retries: 0, **options)
  end
end
