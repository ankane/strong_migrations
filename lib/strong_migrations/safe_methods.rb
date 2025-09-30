module StrongMigrations
  module SafeMethods
    def safe_by_default_method?(method)
      StrongMigrations.safe_by_default && !version_safe? &&
        [:add_index, :add_belongs_to, :add_reference, :remove_index, :add_foreign_key, :add_check_constraint, :change_column_null].include?(method)
    end

    def version_safe?
      version && version <= StrongMigrations.start_after
    end

    def safe_add_index(*args, **options)
      disable_transaction
      @migration.add_index(*args, **options.merge(algorithm: :concurrently))
    end

    def safe_remove_index(*args, **options)
      disable_transaction
      @migration.remove_index(*args, **options.merge(algorithm: :concurrently))
    end

    def safe_add_reference(table, reference, *args, **options)
      @migration.reversible do |dir|
        dir.up do
          disable_transaction
          foreign_key = options.delete(:foreign_key)
          @migration.add_reference(table, reference, *args, **options.merge(index: {algorithm: :concurrently}))
          if foreign_key
            # same as Active Record
            name =
              if foreign_key.is_a?(Hash) && foreign_key[:to_table]
                foreign_key[:to_table]
              else
                reference_table_name(reference)
              end

            foreign_key_opts = foreign_key.is_a?(Hash) ? foreign_key.except(:to_table) : {}
            if reference
              @migration.add_foreign_key(table, name, column: "#{reference}_id", validate: false, **foreign_key_opts)
            else
              @migration.add_foreign_key(table, name, validate: false, **foreign_key_opts)
            end
          end
        end
        dir.down do
          @migration.remove_reference(table, reference)
        end
      end
    end

    def safe_add_foreign_key(from_table, to_table, *args, **options)
      @migration.reversible do |dir|
        dir.up do
          if !connection.foreign_key_exists?(from_table, to_table, **options.merge(validate: false))
            @migration.add_foreign_key(from_table, to_table, *args, **options.merge(validate: false))
          end
          disable_transaction
          @migration.validate_foreign_key(from_table, to_table, **options.slice(:column, :name))
        end
        dir.down do
          @migration.remove_foreign_key(from_table, to_table, **options.slice(:column, :name))
        end
      end
    end

    def safe_add_check_constraint(table, expression, *args, add_options, validate_options)
      @migration.reversible do |dir|
        dir.up do
          # only skip invalid constraints
          unless connection.check_constraints(table).any? { |c| c.options[:name] == validate_options[:name] && !c.options[:validate] }
            @migration.add_check_constraint(table, expression, *args, **add_options)
          end
          disable_transaction
          @migration.validate_check_constraint(table, **validate_options)
        end
        dir.down do
          @migration.remove_check_constraint(table, expression, **add_options.except(:validate))
        end
      end
    end

    def safe_change_column_null(table, column, null, default = nil)
      if !null
        if default.nil?
          # Use the more comprehensive backfill approach for complex cases
          @migration.reversible do |dir|
            dir.up do
              unless default.nil?
                # TODO search for parent model if needed
                if connection.pool != ActiveRecord::Base.connection_pool
                  raise_error :change_column_null,
                    code: backfill_code(table, column, default)
                end

                model =
                  Class.new(ActiveRecord::Base) do
                    self.table_name = table

                    def self.to_s
                      "Backfill"
                    end
                  end

                update_sql =
                  model.connection_pool.with_connection do |c|
                    quoted_column = c.quote_column_name(column)
                    quoted_default = c.quote_default_expression(default, c.send(:column_for, table, column))
                    "#{quoted_column} = #{quoted_default}"
                  end

                @migration.say("Backfilling default")
                disable_transaction
                model.unscoped.in_batches(of: 10000) do |relation|
                  relation.where(column => nil).update_all(update_sql)
                  sleep(0.01)
                end
              end

              @migration.add_check_constraint(table, "#{column} IS NOT NULL", name: "#{table}_#{column}_null", validate: false)
              disable_transaction
              @migration.validate_check_constraint(table, name: "#{table}_#{column}_null")
              @migration.change_column_null(table, column, false)
              @migration.remove_check_constraint(table, name: "#{table}_#{column}_null")
            end
            dir.down do
              @migration.change_column_null(table, column, true)
            end
          end
        else
          # Simple case without default backfill
          @migration.add_check_constraint(table, "#{column} IS NOT NULL", name: "#{table}_#{column}_null", validate: false)
          @migration.validate_check_constraint(table, name: "#{table}_#{column}_null")
          @migration.change_column_null(table, column, false)
          @migration.remove_check_constraint(table, name: "#{table}_#{column}_null")
        end
      else
        @migration.change_column_null(table, column, true)
      end
    end

    private

    # hard to commit at right time when reverting
    # so just commit at start
    def disable_transaction
      if in_transaction? && !transaction_disabled
        connection.commit_db_transaction
        self.transaction_disabled = true
      end
    end

    def in_transaction?
      connection.open_transactions > 0
    end

    def reference_table_name(reference)
      if ActiveRecord::Base.respond_to?(:pluralize_table_names) && ActiveRecord::Base.pluralize_table_names
        reference.to_s.pluralize.to_sym
      else
        reference
      end
    end

    def backfill_code(table, column, default)
      model = table.to_s.classify
      "#{model}.unscoped.in_batches.update_all #{column}: #{default.inspect}"
    end
  end
end