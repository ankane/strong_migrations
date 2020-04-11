# Strong Migrations

Catch unsafe migrations in development

✓ Detects potentially dangerous operations<br />✓ Prevents them from running by default<br />✓ Provides instructions on safer ways to do what you want

Supports for PostgreSQL, MySQL, and MariaDB

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://travis-ci.org/ankane/strong_migrations.svg?branch=master)](https://travis-ci.org/ankane/strong_migrations)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'strong_migrations'
```

We highly recommend [setting timeouts](#timeouts). You can [mark existing migrations as safe](#existing-migrations) as well.

## Checks

Potentially dangerous operations:

- [removing a column](#removing-a-column)
- [adding a column with a default value](#adding-a-column-with-a-default-value)
- [backfilling data](#backfilling-data)
- [changing the type of a column](#renaming-or-changing-the-type-of-a-column)
- [renaming a column](#renaming-or-changing-the-type-of-a-column)
- [renaming a table](#renaming-a-table)
- [creating a table with the force option](#creating-a-table-with-the-force-option)
- [using change_column_null with a default value](#using-change_column_null-with-a-default-value)
- [executing SQL directly](#executing-SQL-directly)

Postgres-specific checks:

- [adding an index non-concurrently](#adding-an-index)
- [removing an index non-concurrently](#removing-an-index)
- [adding a reference](#adding-a-reference)
- [adding a foreign key](#adding-a-foreign-key)
- [adding a json column](#adding-a-json-column)
- [setting NOT NULL on an existing column](#setting-not-null-on-an-existing-column)

Best practices:

- [keeping non-unique indexes to three columns or less](#keeping-non-unique-indexes-to-three-columns-or-less)

You can also add [custom checks](#custom-checks) or [disable specific checks](#disable-checks).

### Removing a column

#### Bad

ActiveRecord caches database columns at runtime, so if you drop a column, it can cause exceptions until your app reboots.

```ruby
class RemoveSomeColumnFromUsers < ActiveRecord::Migration[6.0]
  def change
    remove_column :users, :some_column
  end
end
```

#### Good

1. Tell ActiveRecord to ignore the column from its cache

  ```ruby
  class User < ApplicationRecord
    self.ignored_columns = ["some_column"]
  end
  ```

2. Deploy code
3. Write a migration to remove the column (wrap in `safety_assured` block)

  ```ruby
  class RemoveSomeColumnFromUsers < ActiveRecord::Migration[6.0]
    def change
      safety_assured { remove_column :users, :some_column }
    end
  end
  ```

4. Deploy and run migration

### Adding a column with a default value

Note: This operation is safe in Postgres 11+, MySQL 8.0.12+, and MariaDB 10.3.2+.

#### Bad

Adding a column with a default value to an existing table causes the entire table to be rewritten.

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :some_column, :text, default: "default_value"
  end
end
```

#### Good

Instead, add the column without a default value, then change the default.

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column :users, :some_column, :text
    change_column_default :users, :some_column, "default_value"
  end

  def down
    remove_column :users, :some_column
  end
end
```

See the next section for how to backfill.

### Backfilling data

#### Bad

Backfilling in the same transaction that alters a table locks the table for the [duration of the backfill](https://wework.github.io/data/2015/11/05/add-columns-with-default-values-to-large-tables-in-rails-postgres/).

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :some_column, :text
    User.update_all some_column: "default_value"
  end
end
```

Also, running a single query to update data can cause issues for large tables.

#### Good

There are three keys to backfilling safely: batching, throttling, and running it outside a transaction. Use the Rails console or a separate migration with `disable_ddl_transaction!`.

```ruby
class BackfillSomeColumn < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches do |relation|
      relation.update_all some_column: "default_value"
      sleep(0.01) # throttle
    end
  end
end
```

### Renaming or changing the type of a column

#### Bad

```ruby
class RenameSomeColumn < ActiveRecord::Migration[6.0]
  def change
    rename_column :users, :some_column, :new_name
  end
end
```

or

```ruby
class ChangeSomeColumnType < ActiveRecord::Migration[6.0]
  def change
    change_column :users, :some_column, :new_type
  end
end
```

A few changes are safe in Postgres:

- Changing between `varchar` and `text` columns
- Increasing the precision of a `decimal` or `numeric` column
- Making a `decimal` or `numeric` column unconstrained
- Changing between `timestamp` and `timestamptz` columns when session time zone is UTC in Postgres 12+

And a few in MySQL and MariaDB:

- Increasing the length of a `varchar` column from under 255 up to 255
- Increasing the length of a `varchar` column over 255

#### Good

A safer approach is to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to the new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column

### Renaming a table

#### Bad

```ruby
class RenameUsersToCustomers < ActiveRecord::Migration[6.0]
  def change
    rename_table :users, :customers
  end
end
```

#### Good

A safer approach is to:

1. Create a new table
2. Write to both tables
3. Backfill data from the old table to new table
4. Move reads from the old table to the new table
5. Stop writing to the old table
6. Drop the old table

### Creating a table with the force option

#### Bad

The `force` option can drop an existing table.

```ruby
class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users, force: true do |t|
      # ...
    end
  end
end
```

#### Good

Create tables without the `force` option.

```ruby
class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      # ...
    end
  end
end
```

### Using change_column_null with a default value

#### Bad

This generates a single `UPDATE` statement to set the default value.

```ruby
class ChangeSomeColumnNull < ActiveRecord::Migration[6.0]
  def change
    change_column_null :users, :some_column, false, "default_value"
  end
end
```

#### Good

Backfill the column [safely](#backfilling-data). Then use:

```ruby
class ChangeSomeColumnNull < ActiveRecord::Migration[6.0]
  def change
    change_column_null :users, :some_column, false
  end
end
```

Note: In Postgres, `change_column_null` is still [not safe](#setting-not-null-on-an-existing-column) with this method.

### Executing SQL directly

Strong Migrations can’t ensure safety for directly executed SQL. Make really sure that what you’re doing is safe, then use:

```ruby
class MySafeMigration < ActiveRecord::Migration[6.0]
  def change
    safety_assured { execute "ALTER TABLE ..." }
  end
end
```

### Adding an index

#### Bad

In Postgres, adding an index non-concurrently locks the table.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[6.0]
  def change
    add_index :users, :some_column
  end
end
```

#### Good

Add indexes concurrently.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :users, :some_column, algorithm: :concurrently
  end
end
```

If you forget `disable_ddl_transaction!`, the migration will fail. Also, note that indexes on new tables (those created in the same migration) don’t require this.

With [gindex](https://github.com/ankane/gindex), you can generate an index migration instantly with:

```sh
rails g index table column
```

### Removing an index

Note: This check is [opt-in](#opt-in-checks).

#### Bad

In Postgres, removing an index non-concurrently locks the table for a brief period.

```ruby
class RemoveSomeIndexFromUsers < ActiveRecord::Migration[6.0]
  def change
    remove_index :users, :some_column
  end
end
```

#### Good

Remove indexes concurrently.

```ruby
class RemoveSomeIndexFromUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    remove_index :users, column: :some_column, algorithm: :concurrently
  end
end
```

### Adding a reference

#### Bad

Rails adds an index non-concurrently to references by default, which is problematic for Postgres.

```ruby
class AddReferenceToUsers < ActiveRecord::Migration[6.0]
  def change
    add_reference :users, :city
  end
end
```

#### Good

Make sure the index is added concurrently.

```ruby
class AddReferenceToUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_reference :users, :city, index: {algorithm: :concurrently}
  end
end
```

### Adding a foreign key

#### Bad

In Postgres, new foreign keys are validated by default, which acquires a `ShareRowExclusiveLock` that can be [expensive on large tables](https://travisofthenorth.com/blog/2017/2/2/postgres-adding-foreign-keys-with-zero-downtime).

```ruby
class AddForeignKeyOnUsers < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :users, :orders
  end
end
```

or

```ruby
class AddReferenceToUsers < ActiveRecord::Migration[6.0]
  def change
    add_reference :users, :order, foreign_key: true
  end
end
```

#### Good

Instead, validate it in a separate migration with a more agreeable `RowShareLock`. This approach is documented by Postgres to have “[the least impact on other work](https://www.postgresql.org/docs/current/sql-altertable.html).”

For Rails 5.2+, use:

```ruby
class AddForeignKeyOnUsers < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :users, :orders, validate: false
  end
end
```

Then validate it in a separate migration.

```ruby
class ValidateForeignKeyOnUsers < ActiveRecord::Migration[6.0]
  def change
    validate_foreign_key :users, :orders
  end
end
```

For Rails < 5.2, use:

```ruby
class AddForeignKeyOnUsers < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "fk_rails_c1e9b98e31" FOREIGN KEY ("order_id") REFERENCES "orders" ("id") NOT VALID'
    end
  end
end
```

Then validate it in a separate migration.

```ruby
class ValidateForeignKeyOnUsers < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "fk_rails_c1e9b98e31"'
    end
  end
end
```

### Adding a json column

#### Bad

In Postgres, there’s no equality operator for the `json` column type, which can cause errors for existing `SELECT DISTINCT` queries.

```ruby
class AddPropertiesToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :properties, :json
  end
end
```

#### Good

Use `jsonb` instead.

```ruby
class AddPropertiesToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :properties, :jsonb
  end
end
```

### Setting NOT NULL on an existing column

#### Bad

In Postgres, setting `NOT NULL` on an existing column requires an `AccessExclusiveLock`, which is expensive on large tables.

```ruby
class SetSomeColumnNotNull < ActiveRecord::Migration[6.0]
  def change
    change_column_null :users, :some_column, false
  end
end
```

#### Good

Instead, add a constraint:

```ruby
class SetSomeColumnNotNull < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "users_some_column_null" CHECK ("some_column" IS NOT NULL) NOT VALID'
    end
  end
end
```

Then validate it in a separate migration.

```ruby
class ValidateSomeColumnNotNull < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "users_some_column_null"'
    end
  end
end
```

Note: This is not 100% the same as `NOT NULL` column constraint. Here’s a [good explanation](https://medium.com/doctolib/adding-a-not-null-constraint-on-pg-faster-with-minimal-locking-38b2c00c4d1c).

### Keeping non-unique indexes to three columns or less

#### Bad

Adding a non-unique index with more than three columns rarely improves performance.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[6.0]
  def change
    add_index :users, [:a, :b, :c, :d]
  end
end
```

#### Good

Instead, start an index with columns that narrow down the results the most.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[6.0]
  def change
    add_index :users, [:b, :d]
  end
end
```

For Postgres, be sure to add them concurrently.

## Assuring Safety

To mark a step in the migration as safe, despite using a method that might otherwise be dangerous, wrap it in a `safety_assured` block.

```ruby
class MySafeMigration < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :users, :some_column }
  end
end
```

Certain methods like `execute` and `change_table` cannot be inspected and are prevented from running by default. Make sure what you’re doing is really safe and use this pattern.

## Custom Checks

Add your own custom checks with:

```ruby
StrongMigrations.add_check do |method, args|
  if method == :add_index && args[0].to_s == "users"
    stop! "No more indexes on the users table"
  end
end
```

Use the `stop!` method to stop migrations.

Note: Since `remove_column` always requires a `safety_assured` block, it’s not possible to add a custom check for `remove_column` operations.

## Opt-in Checks

Some operations rarely cause issues in practice, but can be checked if desired. Enable checks with:

```ruby
StrongMigrations.enable_check(:remove_index)
```

To start a check only after a specific migration, use:

```ruby
StrongMigrations.enable_check(:remove_index, start_after: 20170101000000)
```

## Disable Checks

Disable specific checks with:

```ruby
StrongMigrations.disable_check(:add_index)
```

Check the [source code](https://github.com/ankane/strong_migrations/blob/master/lib/strong_migrations.rb) for the list of keys.

## Custom Messages

To customize specific messages, create an initializer with:

```ruby
StrongMigrations.error_messages[:add_column_default] = "Your custom instructions"
```

Check the [source code](https://github.com/ankane/strong_migrations/blob/master/lib/strong_migrations.rb) for the list of keys.

## Timeouts

It’s a good idea to set a long statement timeout and a short lock timeout for migrations. This way, migrations can run for a while, and if a migration can’t acquire a lock in a timely manner, other statements won’t be stuck behind it.

Create `config/initializers/strong_migrations.rb` with:

```ruby
StrongMigrations.statement_timeout = 1.hour
StrongMigrations.lock_timeout = 10.seconds
```

Or set the timeouts directly on the database user that runs migrations. For Postgres, use:

```sql
ALTER ROLE myuser SET statement_timeout = '1h';
ALTER ROLE myuser SET lock_timeout = '10s';
```

Note: If you use PgBouncer in transaction mode, you must set timeouts on the database user.

## Existing Migrations

To mark migrations as safe that were created before installing this gem, create an initializer with:

```ruby
StrongMigrations.start_after = 20170101000000
```

Use the version from your latest migration.

## Target Version

If your development database version is different from production, you can specify the production version so the right checks are run in development.

```ruby
StrongMigrations.target_postgresql_version = "10"
StrongMigrations.target_mysql_version = "8.0.12"
StrongMigrations.target_mariadb_version = "10.3.2"
```

For safety, this option only affects development and test environments. In other environments, the actual server version is always used.

## Analyze Tables

Analyze tables automatically (to update planner statistics) after an index is added. Create an initializer with:

```ruby
StrongMigrations.auto_analyze = true
```

## Faster Migrations

Only dump the schema when adding a new migration. If you use Git, create an initializer with:

```ruby
ActiveRecord::Base.dump_schema_after_migration = Rails.env.development? &&
  `git status db/migrate/ --porcelain`.present?
```

## Schema Sanity

Columns can flip order in `db/schema.rb` when you have multiple developers. One way to prevent this is to [alphabetize them](https://www.pgrs.net/2008/03/12/alphabetize-schema-rb-columns/). Add to the end of your `Rakefile`:

```ruby
task "db:schema:dump": "strong_migrations:alphabetize_columns"
```

## Dangerous Tasks

For safety, dangerous database tasks are disabled in production - `db:drop`, `db:reset`, `db:schema:load`, and `db:structure:load`. To get around this, use:

```sh
SAFETY_ASSURED=1 rails db:drop
```

## Permissions

We recommend using a [separate database user](https://ankane.org/postgres-users) for migrations when possible so you don’t need to grant your app user permission to alter tables.

## Additional Reading

- [Rails Migrations with No Downtime](https://pedro.herokuapp.com/past/2011/7/13/rails_migrations_with_no_downtime/)
- [PostgreSQL at Scale: Database Schema Changes Without Downtime](https://medium.com/braintree-product-technology/postgresql-at-scale-database-schema-changes-without-downtime-20d3749ed680)

## Credits

Thanks to Bob Remeika and David Waller for the [original code](https://github.com/foobarfighter/safe-migrations) and [Sean Huber](https://github.com/LendingHome/zero_downtime_migrations) for the bad/good readme format.

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/strong_migrations/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/strong_migrations/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/ankane/strong_migrations.git
cd strong_migrations
bundle install

# Postgres
createdb strong_migrations_test
bundle exec rake test

# MySQL and MariaDB
mysqladmin create strong_migrations_test
ADAPTER=mysql2 bundle exec rake test
```
