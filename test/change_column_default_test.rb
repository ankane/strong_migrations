require_relative "test_helper"

class ChangeColumnDefaultTest < Minitest::Test
  def test_partial_inserts
    with_partial_inserts(true) do
      assert_unsafe ChangeColumnDefault
    end
  end

  def test_partial_inserts_hash
    with_partial_inserts(true) do
      assert_unsafe ChangeColumnDefaultHash
    end
  end

  def test_no_partial_inserts
    with_partial_inserts(false) do
      assert_safe ChangeColumnDefaultHash
    end
  end

  def test_new_column
    assert_safe ChangeColumnDefaultNewColumn
  end

  def test_default
    # Rails 7 disables partial inserts by default
    # but Active Record 7 by itself does not
    assert_unsafe ChangeColumnDefault
  end

  def with_partial_inserts(value, &block)
    ActiveRecord::Base.stub(:partial_inserts, value, &block)
  end
end
