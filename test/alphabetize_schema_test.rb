require_relative "test_helper"

class AlphabetizeSchemaTest < Minitest::Test
  def test_default
    schema = dump_schema

    expected_columns = <<-EOS
    t.string "name"
    t.string "city"
    EOS
    assert_match expected_columns, schema
  end

  def test_enabled
    schema =
      StrongMigrations.stub(:alphabetize_schema, true) do
        dump_schema
      end

    expected_columns = <<-EOS
    t.string "name"
    t.bigint "order_id"
    EOS
    assert_match expected_columns, schema
  end

  private

  def dump_schema
    require "stringio"

    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection_class, io)
    io.string
  end
end
