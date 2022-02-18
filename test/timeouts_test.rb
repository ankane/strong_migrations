require_relative "test_helper"

class TimeoutsTest < Minitest::Test
  def teardown
    reset_timeouts
  end

  def test_timeouts
    skip unless postgresql? || mysql? || mariadb?

    StrongMigrations.statement_timeout = 1.hour
    StrongMigrations.lock_timeout = 10.seconds

    migrate CheckTimeouts

    if postgresql?
      assert_equal "1h", $statement_timeout
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

  def test_lock_timeout_float
    skip unless postgresql?

    StrongMigrations.lock_timeout = 0.5.seconds

    migrate CheckTimeouts

    assert_equal "500ms", $lock_timeout
  end

  def test_timeouts_string
    skip unless postgresql?

    StrongMigrations.statement_timeout = "1h"
    StrongMigrations.lock_timeout = "1d"

    migrate CheckTimeouts

    assert_equal "1h", $statement_timeout
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
    with_lock_timeout_retries do
      assert_raises(ActiveRecord::LockWaitTimeout) do
        migrate CheckLockTimeoutRetries
      end
      # MySQL and MariaDB do not support DDL transactions
      assert_equal (postgresql? ? 2 : 1), $migrate_attempts
    end
  end

  def test_lock_timeout_retries_transaction
    with_lock_timeout_retries do
      assert_raises(ActiveRecord::LockWaitTimeout) do
        migrate CheckLockTimeoutRetriesTransaction
      end
      # retries just transaction block
      assert_equal 1, $migrate_attempts
      assert_equal 2, $transaction_attempts
    end
  end

  def test_lock_timeout_retries_transaction_ddl_transaction
    with_lock_timeout_retries do
      assert_raises(ActiveRecord::LockWaitTimeout) do
        migrate CheckLockTimeoutRetriesTransactionDdlTransaction
      end
      # retries entire migration, not transaction block alone
      assert_equal 2, $migrate_attempts
      assert_equal 2, $transaction_attempts
    end
  end

  def test_lock_timeout_retries_no_ddl_transaction
    with_lock_timeout_retries do
      assert_raises(ActiveRecord::LockWaitTimeout) do
        migrate CheckLockTimeoutRetriesNoDdlTransaction
      end
      # retries only single statement, not migration
      assert_equal 1, $migrate_attempts
    end
  end

  def test_lock_timeout_retries_commit_db_transaction
    with_lock_timeout_retries do
      assert_raises(ActiveRecord::LockWaitTimeout) do
        migrate CheckLockTimeoutRetriesCommitDbTransaction
      end
      # does not retry since outside DDL transaction
      assert_equal 1, $migrate_attempts
    end
  end

  def reset_timeouts
    StrongMigrations.lock_timeout = nil
    StrongMigrations.statement_timeout = nil
    if postgresql?
      ActiveRecord::Base.connection.execute("RESET lock_timeout")
      ActiveRecord::Base.connection.execute("RESET statement_timeout")
    elsif mysql?
      ActiveRecord::Base.connection.execute("SET max_execution_time = DEFAULT")
      ActiveRecord::Base.connection.execute("SET lock_wait_timeout = DEFAULT")
    elsif mariadb?
      ActiveRecord::Base.connection.execute("SET max_statement_time = DEFAULT")
      ActiveRecord::Base.connection.execute("SET lock_wait_timeout = DEFAULT")
    end
  end

  def with_lock_timeout_retries
    StrongMigrations.lock_timeout = postgresql? ? 0.1 : 1
    StrongMigrations.lock_timeout_retries = 1
    StrongMigrations.lock_timeout_retry_delay = 0
    $migrate_attempts = 0
    $transaction_attempts = 0

    connection = ActiveRecord::Base.connection_pool.checkout
    if postgresql?
      connection.transaction do
        connection.execute("LOCK TABLE users IN ACCESS EXCLUSIVE MODE")
        yield
      end
    else
      begin
        connection.execute("LOCK TABLE users WRITE")
        yield
      ensure
        connection.execute("UNLOCK TABLES")
      end
    end
  ensure
    StrongMigrations.lock_timeout_retries = 0
    StrongMigrations.lock_timeout_retry_delay = 5
    ActiveRecord::Base.connection_pool.checkin(connection) if connection
  end
end
