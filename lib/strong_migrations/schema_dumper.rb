module StrongMigrations
  module SchemaDumper
    def tables(stream)
      super
      null_constraints(stream)
    end

    def null_constraints(stream)
      statement = <<-SQL
        SELECT t1.oid::regclass::text AS table, a1.attname AS column, c.conname AS name
        FROM pg_constraint c
        JOIN pg_class t1 ON c.conrelid = t1.oid
        JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
        JOIN pg_namespace t3 ON c.connamespace = t3.oid
        WHERE c.contype = 'c'
          AND t3.nspname = ANY (current_schemas(false))
          AND c.consrc = '(' || a1.attname || ' IS NOT NULL)'
        ORDER BY 1, 3
      SQL

      constraints = @connection.select_all(statement.squish).to_a
      constraints.each do |constraint|
        next if ignored?(constraint["table"])
        str = "  add_null_constraint %s, %s, name: %s" % [constraint["table"], constraint["column"], constraint["name"]].map { |s| s.inspect }
        stream.puts(str)
      end
    end
  end
end
