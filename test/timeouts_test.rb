require_relative "test_helper"

class TimeoutsTest < Minitest::Test
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
  ensure
    reset_timeouts
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
  ensure
    reset_timeouts
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
  ensure
    reset_timeouts
  end

  def test_lock_timeout_float
    skip unless postgresql?

    StrongMigrations.lock_timeout = 0.5.seconds

    migrate CheckTimeouts

    assert_equal "500ms", $lock_timeout
  ensure
    reset_timeouts
  end

  def test_timeouts_string
    skip unless postgresql?

    StrongMigrations.statement_timeout = "1h"
    StrongMigrations.lock_timeout = "1d"

    migrate CheckTimeouts

    assert_equal "1h", $statement_timeout
    assert_equal "1d", $lock_timeout
  ensure
    reset_timeouts
  end

  def test_lock_timeout_limit
    StrongMigrations.lock_timeout_limit = 10.seconds
    StrongMigrations.lock_timeout = 20.seconds

    assert_output(nil, /Lock timeout is longer than 10 seconds/) do
      migrate CheckLockTimeout
    end
  ensure
    StrongMigrations.lock_timeout_limit = nil
    reset_timeouts
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
end
