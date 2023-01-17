require_relative "test_helper"

class AlphabetizeSchemaTest < Minitest::Test
  def test_default
    schema = dump_schema

    if postgresql?
      expected_extensions = <<-EOS
  enable_extension "btree_gist"
  enable_extension "citext"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
      EOS
      assert_match expected_extensions, schema
    end

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

    if postgresql?
      expected_extensions = <<-EOS
  enable_extension "btree_gist"
  enable_extension "citext"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
      EOS
      assert_match expected_extensions, schema
    end

    expected_columns = <<-EOS
    t.text "description"
    t.string "interval"
    t.string "name"
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
