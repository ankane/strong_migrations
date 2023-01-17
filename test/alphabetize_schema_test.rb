require_relative "test_helper"

class AlphabetizeSchemaTest < Minitest::Test
  def test_default
    schema = dump_schema

    expected_columns = <<-EOS
  create_table "users", force: :cascade do |t|
    t.string "name"
    EOS
    assert_match expected_columns, schema
  end

  def test_enabled
    schema =
      StrongMigrations.stub(:alphabetize_schema, true) do
        dump_schema
      end

    expected_columns = <<-EOS
  create_table "users", force: :cascade do |t|
    t.string "city"
    EOS
    assert_match expected_columns, schema
  end

  private

  def dump_schema
    require "stringio"

    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, io)
    io.string
  end
end
