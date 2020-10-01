# Strong Migrations

Catch unsafe migrations in development

&nbsp;&nbsp;✓&nbsp;&nbsp;Detects potentially dangerous operations<br />&nbsp;&nbsp;✓&nbsp;&nbsp;Prevents them from running by default<br />&nbsp;&nbsp;✓&nbsp;&nbsp;Provides instructions on safer ways to do what you want

Supports for PostgreSQL, MySQL, and MariaDB

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://travis-ci.org/ankane/strong_migrations.svg?branch=master)](https://travis-ci.org/ankane/strong_migrations)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'strong_migrations'
```

And run:

```sh
bundle install
rails generate strong_migrations:install
```

Strong Migrations sets a long statement timeout for migrations so you can set a [short statement timeout](#app-timeouts) for your application.

## How It Works

When you run a migration that’s potentially dangerous, you’ll see an error message like:

```txt
=== Dangerous operation detected #strong_migrations ===

Active Record caches attributes, which causes problems
when removing columns. Be sure to ignore the column:

class User < ApplicationRecord
  self.ignored_columns = ["name"]
end

Deploy the code, then wrap this step in a safety_assured { ... } block.

class RemoveColumn < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :users, :name }
  end
end
```

An operation is classified as dangerous if it either:

- Blocks reads or writes for more than a few seconds (after a lock is acquired)
- Has a good chance of causing application errors

## Checks

Potentially dangerous operations:

- [removing a column](#removing-a-column)
- [adding a column with a default value](#adding-a-column-with-a-default-value)
- [backfilling data](#backfilling-data)
- [changing the type of a column](#changing-the-type-of-a-column)
- [renaming a column](#renaming-a-column)
- [renaming a table](#renaming-a-table)
- [creating a table with the force option](#creating-a-table-with-the-force-option)
- [setting NOT NULL on an existing column](#setting-not-null-on-an-existing-column)
- [executing SQL directly](#executing-SQL-directly)

Postgres-specific checks:

- [adding an index non-concurrently](#adding-an-index-non-concurrently)
- [adding a reference](#adding-a-reference)
- [adding a foreign key](#adding-a-foreign-key)
- [adding a json column](#adding-a-json-column)

Best practices:

- [keeping non-unique indexes to three columns or less](#keeping-non-unique-indexes-to-three-columns-or-less)

You can also add [custom checks](#custom-checks) or [disable specific checks](#disable-checks).

### Removing a column

#### Bad

Active Record caches database columns at runtime, so if you drop a column, it can cause exceptions until your app reboots.

```ruby
class RemoveSomeColumnFromUsers < ActiveRecord::Migration[6.0]
  def change
    remove_column :users, :some_column
  end
end
```

#### Good

1. Tell Active Record to ignore the column from its cache

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

#### Bad

In earlier versions of Postgres, MySQL, and MariaDB, adding a column with a default value to an existing table causes the entire table to be rewritten. During this time, reads and writes are blocked in Postgres, and writes are blocked in MySQL and MariaDB.

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :some_column, :text, default: "default_value"
  end
end
```

In Postgres 11+, MySQL 8.0.12+, and MariaDB 10.3.2+, this no longer requires a table rewrite and is safe.

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

Active Record creates a transaction around each migration, and backfilling in the same transaction that alters a table keeps the table locked for the [duration of the backfill](https://wework.github.io/data/2015/11/05/add-columns-with-default-values-to-large-tables-in-rails-postgres/).

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

### Changing the type of a column

#### Bad

Changing the type of a column causes the entire table to be rewritten. During this time, reads and writes are blocked in Postgres, and writes are blocked in MySQL and MariaDB.

```ruby
class ChangeSomeColumnType < ActiveRecord::Migration[6.0]
  def change
    change_column :users, :some_column, :new_type
  end
end
```

A few changes don’t require a table rewrite (and are safe) in Postgres:

- Increasing the length limit of a `varchar` column (or removing the limit)
- Changing a `varchar` column to a `text` column
- Changing a `text` column to a `varchar` column with no length limit
- Increasing the precision of a `decimal` or `numeric` column
- Making a `decimal` or `numeric` column unconstrained
- Changing between `timestamp` and `timestamptz` columns when session time zone is UTC in Postgres 12+

And a few in MySQL and MariaDB:

- Increasing the length limit of a `varchar` column from under 255 up to 255
- Increasing the length limit of a `varchar` column from over 255 to the max limit

#### Good

A safer approach is to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to the new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column

### Renaming a column

#### Bad

Renaming a column that’s in use will cause errors in your application.

```ruby
class RenameSomeColumn < ActiveRecord::Migration[6.0]
  def change
    rename_column :users, :some_column, :new_name
  end
end
```

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

Renaming a table that’s in use will cause errors in your application.

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

If you intend to drop an existing table, run `drop_table` first.

### Setting NOT NULL on an existing column

#### Bad

Setting `NOT NULL` on an existing column blocks reads and writes while every row is checked.

```ruby
class SetSomeColumnNotNull < ActiveRecord::Migration[6.0]
  def change
    change_column_null :users, :some_column, false
  end
end
```

#### Good - Postgres

Instead, add a check constraint:

```ruby
class SetSomeColumnNotNull < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      execute 'ALTER TABLE "users" ADD CONSTRAINT "users_some_column_null" CHECK ("some_column" IS NOT NULL) NOT VALID'
    end
  end
end
```

Then validate it in a separate migration. A `NOT NULL` check constraint is [functionally equivalent](https://medium.com/doctolib/adding-a-not-null-constraint-on-pg-faster-with-minimal-locking-38b2c00c4d1c) to setting `NOT NULL` on the column, but it won’t show up in `schema.rb`. In Postgres 12+, once the check constraint is validated, you can safely set `NOT NULL` on the column and drop the check constraint.

```ruby
class ValidateSomeColumnNotNull < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      execute 'ALTER TABLE "users" VALIDATE CONSTRAINT "users_some_column_null"'
    end

    # in Postgres 12+, you can then safely set NOT NULL on the column
    change_column_null :users, :some_column, false
    safety_assured do
      execute 'ALTER TABLE "users" DROP CONSTRAINT "users_some_column_null"'
    end
  end
end
```

#### Good - MySQL and MariaDB

[Let us know](https://github.com/ankane/strong_migrations/issues/new) if you have a safe way to do this.

### Executing SQL directly

Strong Migrations can’t ensure safety for raw SQL statements. Make really sure that what you’re doing is safe, then use:

```ruby
class ExecuteSQL < ActiveRecord::Migration[6.0]
  def change
    safety_assured { execute "..." }
  end
end
```

### Adding an index non-concurrently

#### Bad

In Postgres, adding an index non-concurrently blocks writes.

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

### Adding a reference

#### Bad

Rails adds an index non-concurrently to references by default, which blocks writes in Postgres.

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

In Postgres, adding a foreign key blocks writes on both tables.

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

Add the foreign key without validating existing rows, then validate them in a separate migration.

For Rails 5.2+, use:

```ruby
class AddForeignKeyOnUsers < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :users, :orders, validate: false
  end
end
```

Then:

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

Then:

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

In Postgres, there’s no equality operator for the `json` column type, which can cause errors for existing `SELECT DISTINCT` queries in your application.

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

### Removing an index non-concurrently

Postgres supports removing indexes concurrently, but removing them non-concurrently shouldn’t be an issue for most applications. You can enable this check with:

```ruby
StrongMigrations.enable_check(:remove_index)
```

## Disable Checks

Disable specific checks with:

```ruby
StrongMigrations.disable_check(:add_index)
```

Check the [source code](https://github.com/ankane/strong_migrations/blob/master/lib/strong_migrations.rb) for the list of keys.

## Down Migrations / Rollbacks

By default, checks are disabled when migrating down. Enable them with:

```ruby
StrongMigrations.check_down = true
```

## Custom Messages

To customize specific messages, create an initializer with:

```ruby
StrongMigrations.error_messages[:add_column_default] = "Your custom instructions"
```

Check the [source code](https://github.com/ankane/strong_migrations/blob/master/lib/strong_migrations.rb) for the list of keys.

## Migration Timeouts

It’s extremely important to set a short lock timeout for migrations. This way, if a migration can’t acquire a lock in a timely manner, other statements won’t be stuck behind it. We also recommend setting a long statement timeout so migrations can run for a while.

Create `config/initializers/strong_migrations.rb` with:

```ruby
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour
```

Or set the timeouts directly on the database user that runs migrations. For Postgres, use:

```sql
ALTER ROLE myuser SET lock_timeout = '10s';
ALTER ROLE myuser SET statement_timeout = '1h';
```

Note: If you use PgBouncer in transaction mode, you must set timeouts on the database user.

## App Timeouts

We recommend adding timeouts to `config/database.yml` to prevent connections from hanging and individual queries from taking up too many resources in controllers, jobs, the Rails console, and other places.

For Postgres:

```yml
production:
  connect_timeout: 5
  variables:
    statement_timeout: 15s
    lock_timeout: 10s
```

Note: If you use PgBouncer in transaction mode, you must set the statement and lock timeouts on the database user as shown above.

For MySQL:

```yml
production:
  connect_timeout: 5
  read_timeout: 5
  write_timeout: 5
  variables:
    max_execution_time: 15000 # ms
    lock_wait_timeout: 10 # sec

```

For MariaDB:

```yml
production:
  connect_timeout: 5
  read_timeout: 5
  write_timeout: 5
  variables:
    max_statement_time: 15 # sec
    lock_wait_timeout: 10 # sec
```

For HTTP connections, Redis, and other services, check out [this guide](https://github.com/ankane/the-ultimate-guide-to-ruby-timeouts).

## Existing Migrations

To mark migrations as safe that were created before installing this gem, create an initializer with:

```ruby
StrongMigrations.start_after = 20170101000000
```

Use the version from your latest migration.

## Target Version

If your development database version is different from production, you can specify the production version so the right checks run in development.

```ruby
StrongMigrations.target_version = 10 # or "8.0.12", "10.3.2", etc
```

The major version works well for Postgres, while the full version is recommended for MySQL and MariaDB.

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

## Permissions

We recommend using a [separate database user](https://ankane.org/postgres-users) for migrations when possible so you don’t need to grant your app user permission to alter tables.

## Smaller Projects

You probably don’t need this gem for smaller projects, as operations that are unsafe at scale can be perfectly safe on smaller, low-traffic tables.

## Additional Reading

- [Rails Migrations with No Downtime](https://pedro.herokuapp.com/past/2011/7/13/rails_migrations_with_no_downtime/)
- [PostgreSQL at Scale: Database Schema Changes Without Downtime](https://medium.com/braintree-product-technology/postgresql-at-scale-database-schema-changes-without-downtime-20d3749ed680)
- [An Overview of DDL Algorithms in MySQL](https://mydbops.wordpress.com/2020/03/04/an-overview-of-ddl-algorithms-in-mysql-covers-mysql-8/)
- [MariaDB InnoDB Online DDL Overview](https://mariadb.com/kb/en/innodb-online-ddl-overview/)

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
