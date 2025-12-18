require_relative "test_helper"

class AlphabetizeSchemaTest < Minitest::Test
  def test_default
    schema = dump_schema

    if ActiveRecord::VERSION::STRING.to_f >= 8.1
      expected_columns = <<-EOS
    t.string "name"
    t.bigint "order_id"
      EOS
    else
      expected_columns = <<-EOS
    t.string "name"
    t.string "city"
      EOS
    end
    assert_match expected_columns, schema
  end

  def test_enabled
    schema =
      with_option(:alphabetize_schema, true) do
        dump_schema
      end

    expected_columns = <<-EOS
    t.string "name"
    t.bigint "order_id"
    EOS
    assert_match expected_columns, schema
  end

  def test_virtual_column
    skip unless mysql? || mariadb?

    migrate AddColumnGeneratedVirtual
    schema =
      with_option(:alphabetize_schema, true) do
        dump_schema
      end
    migrate AddColumnGeneratedVirtual, direction: :down
    assert_match "t.virtual", schema
  end

  private

  def dump_schema
    require "stringio"

    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection_class, io)
    io.string
  end
end
