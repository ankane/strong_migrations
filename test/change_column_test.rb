require_relative "test_helper"

class ChangeColumnTest < Minitest::Test
  def test_unsafe
    assert_unsafe ChangeColumn
  end

  def test_varchar_to_text
    skip unless postgresql?
    assert_safe ChangeColumnVarcharToText
  end

  def test_varchar_to_citext
    skip unless postgresql?
    assert_safe ChangeColumnVarcharToCitext
  end

  def test_varchar_increase_limit
    assert_safe ChangeColumnVarcharIncreaseLimit
  end

  def test_varchar_increase_limit_over_256
    if postgresql?
      assert_safe ChangeColumnVarcharIncreaseLimit256
    elsif mysql? || mariadb?
      assert_unsafe ChangeColumnVarcharIncreaseLimit256
    end
  end

  def test_varchar_decrease_limit
    assert_unsafe ChangeColumnVarcharDecreaseLimit
  end

  def test_varchar_remove_limit
    skip unless postgresql?
    assert_safe ChangeColumnVarcharRemoveLimit
  end

  def test_text_to_varchar_limit
    skip unless postgresql?
    assert_unsafe ChangeColumnTextToVarcharLimit
  end

  def test_text_to_varchar_no_limit
    skip unless postgresql?
    assert_safe ChangeColumnTextToVarcharNoLimit
  end

  def test_varchar_add_limit
    skip unless postgresql?
    assert_unsafe ChangeColumnVarcharAddLimit
  end

  def test_text_to_citext
    skip unless postgresql?
    assert_safe ChangeColumnTextToCitext
  end

  def test_citext_to_text
    skip unless postgresql?
    assert_safe ChangeColumnCitextToText
  end

  def test_citext_to_varchar_limit
    skip unless postgresql?
    assert_unsafe ChangeColumnCitextToVarcharLimit
  end

  def test_citext_to_varchar_no_limit
    skip unless postgresql?
    assert_safe ChangeColumnCitextToVarcharNoLimit
  end

  def test_decimal_decrease_precision
    skip unless postgresql?
    assert_unsafe ChangeColumnDecimalDecreasePrecision
  end

  def test_decimal_change_scale
    skip unless postgresql?
    assert_unsafe ChangeColumnDecimalChangeScale
  end

  def test_decimal_increase_precision
    skip unless postgresql?
    assert_safe ChangeColumnDecimalIncreasePrecision
  end

  def test_decimal_unconstrained
    skip unless postgresql?
    assert_safe ChangeColumnDecimalIncreasePrecision
  end

  def test_timestamps
    skip unless postgresql?

    with_target_version(12) do
      assert_safe ChangeColumnTimestamps
    end
  end

  def test_timestamps_non_utc
    skip unless postgresql?

    with_target_version(12) do
      with_time_zone do
        assert_unsafe ChangeColumnTimestamps
      end
    end
  end

  def test_timestamps_unsafe
    skip unless postgresql?

    with_target_version(11) do
      assert_unsafe ChangeColumnTimestamps
    end
  end

  def test_datetime_increase_precision
    skip unless postgresql?
    assert_safe ChangeColumnDatetimeIncreasePrecision
  end

  def test_datetime_decrease_precision
    skip unless postgresql?
    assert_unsafe ChangeColumnDatetimeDecreasePrecision
  end

  def test_timestamp_increase_limit
    skip unless postgresql?
    assert_safe ChangeColumnTimestampIncreaseLimit
  end

  def test_timestamp_decrease_limit
    skip unless postgresql?
    assert_unsafe ChangeColumnTimestampDecreaseLimit
  end

  def test_timestamptz_increase_limit
    skip unless postgresql?
    assert_safe ChangeColumnTimestamptzIncreaseLimit
  end

  def test_timestamptz_decrease_limit
    skip unless postgresql?
    assert_unsafe ChangeColumnTimestamptzDecreaseLimit
  end

  def test_interval_increase_precision
    skip unless postgresql?
    assert_safe ChangeColumnIntervalIncreasePrecision
  end

  def test_interval_decrease_precision
    skip unless postgresql?
    assert_unsafe ChangeColumnIntervalDecreasePrecision
  end

  def test_with_not_null
    assert_unsafe ChangeColumnWithNotNull
  end

  def with_time_zone
    ActiveRecord::Base.connection.execute("SET timezone = 'America/Los_Angeles'")
    yield
  ensure
    ActiveRecord::Base.connection.execute("SET timezone = 'UTC'")
  end
end
