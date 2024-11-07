module StrongMigrations
  module SafeMethods
    def safe_by_default_method?(method)
      StrongMigrations.safe_by_default && [:add_index, :add_belongs_to, :add_reference, :remove_index, :add_foreign_key, :add_check_constraint, :change_column_null].include?(method)
    end

    def safe_add_index(*args, **options)
      disable_transaction
      if direction == :up && (index_name = invalid_index_name(*args, **options))
        @migration.safety_assured do
          # TODO pass index schema for extra safety?
          @migration.execute("REINDEX INDEX CONCURRENTLY #{connection.quote_table_name(index_name)}")
        end
      else
        @migration.add_index(*args, **options.merge(algorithm: :concurrently))
      end
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
          @migration.add_reference(table, reference, *args, **options)
          if foreign_key
            # same as Active Record
            name =
              if foreign_key.is_a?(Hash) && foreign_key[:to_table]
                foreign_key[:to_table]
              else
                (ActiveRecord::Base.pluralize_table_names ? reference.to_s.pluralize : reference).to_sym
              end

            foreign_key_opts = foreign_key.is_a?(Hash) ? foreign_key.except(:to_table) : {}
            if reference
              @migration.add_foreign_key(table, name, column: "#{reference}_id", **foreign_key_opts)
            else
              @migration.add_foreign_key(table, name, **foreign_key_opts)
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
          if ar_version < 7.1 || !connection.foreign_key_exists?(from_table, to_table, **options.merge(validate: false))
            @migration.add_foreign_key(from_table, to_table, *args, **options.merge(validate: false))
          end
          disable_transaction
          @migration.validate_foreign_key(from_table, to_table, **options.slice(:column, :name))
        end
        dir.down do
          remove_options = options.slice(:column, :name)
          @migration.remove_foreign_key(from_table, to_table, **remove_options)
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

    def safe_change_column_null(add_args, validate_args, change_args, remove_args, default, constraints)
      @migration.reversible do |dir|
        dir.up do
          unless default.nil?
            raise Error, "default value not supported yet with safe_by_default"
          end

          add_options = add_args.extract_options!
          validate_options = validate_args.extract_options!
          remove_options = remove_args.extract_options!

          # only skip invalid constraints
          unless constraints.any? { |c| c.options[:name] == validate_options[:name] && !c.options[:validate] }
            @migration.add_check_constraint(*add_args, **add_options)
          end
          disable_transaction

          connection.begin_db_transaction
          @migration.validate_check_constraint(*validate_args, **validate_options)
          @migration.change_column_null(*change_args)
          @migration.remove_check_constraint(*remove_args, **remove_options)
          connection.commit_db_transaction
        end
        dir.down do
          down_args = change_args.dup
          down_args[2] = true
          @migration.change_column_null(*down_args)
        end
      end
    end

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

    def invalid_index_name(*args, **options)
      return nil unless connection.index_exists?(*args, **options.merge(valid: false))

      table, columns = args
      index_name = options.fetch(:name, connection.index_name(table, columns))

      # valid option is ignored for Active Record < 7.1, so need to check name as well
      return nil unless ar_version >= 7.1 || adapter.index_invalid?(table, index_name)

      index_name
    end
  end
end
