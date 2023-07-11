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

  def with_partial_inserts(value, &block)
    if ActiveRecord::VERSION::MAJOR >= 7
      ActiveRecord::Base.stub(:partial_inserts, value, &block)
    else
      ActiveRecord::Base.stub(:partial_writes, value, &block)
    end
  end
end
