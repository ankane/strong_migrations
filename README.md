# Strong Migrations

Catch unsafe migrations at dev time

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://travis-ci.org/ankane/strong_migrations.svg?branch=master)](https://travis-ci.org/ankane/strong_migrations)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'strong_migrations'
```

## How It Works

Strong Migrations detects potentially dangerous operations in migrations, prevents them from running by default, and provides instructions on safer ways to do what you want.

![Screenshot](https://ankane.org/images/strong-migrations.png)

## Dangerous Operations

The following operations can cause downtime or errors:

- [[+]](#removing-a-column) removing a column
- [[+]](#adding-a-column-with-a-default-value) adding a column with a non-null default value to an existing table
- [[+]](#backfilling-data) backfilling data
- [[+]](#adding-an-index) adding an index non-concurrently
- [[+]](#adding-a-reference) adding a reference
- [[+]](#adding-a-foreign-key) adding a foreign key
- [[+]](#renaming-or-changing-the-type-of-a-column) changing the type of a column
- [[+]](#renaming-or-changing-the-type-of-a-column) renaming a column
- [[+]](#renaming-a-table) renaming a table
- [[+]](#creating-a-table-with-the-force-option) creating a table with the `force` option
- [[+]](#using-change_column_null-with-a-default-value) using `change_column_null` with a default value
- [[+]](#adding-a-json-column) adding a `json` column

Also checks for best practices:

- [[+]](#) keeping non-unique indexes to three columns or less

## The Zero Downtime Way

### Removing a column

#### Bad

ActiveRecord caches database columns at runtime, so if you drop a column, it can cause exceptions until your app reboots.

```ruby
class RemoveSomeColumnFromUsers < ActiveRecord::Migration[5.2]
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
  class RemoveSomeColumnFromUsers < ActiveRecord::Migration[5.2]
    def change
      safety_assured { remove_column :users, :some_column }
    end
  end
  ```

4. Deploy and run migration

### Adding a column with a default value

#### Bad

Adding a column with a non-null default causes the entire table to be rewritten.

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :some_column, :text, default: "default_value"
  end
end
```

> This operation is safe in Postgres 11+

#### Good

Instead, add the column without a default value, then change the default.

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration[5.2]
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
class AddSomeColumnToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :some_column, :text
    User.update_all some_column: "default_value"
  end
end
```

Also, running a single query to update data can cause issues for large tables.

#### Good

There are three keys: batching, throttling, and running it outside a transaction. Use the Rails console or a separate migration with `disable_ddl_transaction!`.

```ruby
class BackfillSomeColumn < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    User.in_batches do |relation|
      relation.update_all some_column: "default_value"
      sleep(0.1) # throttle
    end
  end
end
```

### Adding an index

#### Bad

In Postgres, adding a non-concurrent indexes lock the table.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :some_column
  end
end
```

#### Good

Add indexes concurrently.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :users, :some_column, algorithm: :concurrently
  end
end
```

If you forget `disable_ddl_transaction!`, the migration will fail. Also, note that indexes on new tables (those created in the same migration) don’t require this. Check out [gindex](https://github.com/ankane/gindex) to quickly generate index migrations without memorizing the syntax.

### Adding a reference

#### Bad

Rails adds a non-concurrent index to references by default, which is problematic for Postgres.

```ruby
class AddReferenceToUsers < ActiveRecord::Migration[5.2]
  def change
    add_reference :users, :city
  end
end
```

#### Good

Make sure the index is added concurrently.

```ruby
class AddReferenceToUsers < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_reference :users, :city, index: false
    add_index :users, :city_id, algorithm: :concurrently
  end
end
```

For polymorphic references, add a compound index on type and id.

### Adding a foreign key

#### Bad

In Postgres, new foreign keys are validated by default, which acquires an `AccessExclusiveLock` that can be [expensive on large tables](https://travisofthenorth.com/blog/2017/2/2/postgres-adding-foreign-keys-with-zero-downtime).

```ruby
class AddForeignKeyOnUsers < ActiveRecord::Migration[5.2]
  def change
    add_foreign_key :users, :orders
  end
end
```

#### Good

Instead, validate it in a separate migration with a more agreeable `RowShareLock`. This approach is documented by Postgres to have “[the least impact on other work](https://www.postgresql.org/docs/current/sql-altertable.html).”

For Rails 5.2+, use:

```ruby
class AddForeignKeyOnUsers < ActiveRecord::Migration[5.2]
  def change
    add_foreign_key :users, :orders, validate: false
  end
end
```

Then validate it in a separate migration.

```ruby
class ValidateForeignKeyOnUsers < ActiveRecord::Migration[5.2]
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

### Renaming or changing the type of a column

#### Bad

```ruby
class RenameSomeColumn < ActiveRecord::Migration[5.2]
  def change
    rename_column :users, :some_column, :new_name
  end
end
```

or

```ruby
class ChangeSomeColumnType < ActiveRecord::Migration[5.2]
  def change
    change_column :users, :some_column, :new_type
  end
end
```

One exception is changing a `varchar` column to `text`, which is safe in Postgres.

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
class RenameUsersToCustomers < ActiveRecord::Migration[5.2]
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

### Creating a table with the `force` option

#### Bad

The `force` option can drop an existing table.

```ruby
class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users, force: true do |t|
      # ...
    end
  end
end
```

#### Good

If you intend to drop a table, do it explicitly. Then create the new table without the `force` option:

```ruby
class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      # ...
    end
  end
end
```

### Using `change_column_null` with a default value

#### Bad

This generates a single `UPDATE` statement to set the default value.

```ruby
class ChangeSomeColumnNull < ActiveRecord::Migration[5.2]
  def change
    change_column_null :users, :some_column, false, "default_value"
  end
end
```

#### Good

Backfill the column [safely](#backfilling-data). Then use:

```ruby
class ChangeSomeColumnNull < ActiveRecord::Migration[5.2]
  def change
    change_column_null :users, :some_column, false
  end
end
```

### Adding a json column

#### Bad

In Postgres, there’s no equality operator for the `json` column type, which causes issues for `SELECT DISTINCT` queries.

```ruby
class AddPropertiesToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :properties, :json
  end
end
```

#### Good

Use `jsonb` instead.

```ruby
class AddPropertiesToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :properties, :jsonb
  end
end
```

## Best Practices

### Keeping non-unique indexes to three columns or less

#### Bad

Adding an index with more than three columns only helps on extremely large tables.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, [:a, :b, :c, :d]
  end
end
```

#### Good

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, [:a, :b, :c]
  end
end
```

> For Postgres, be sure to add them concurrently

## Assuring Safety

To mark a step in the migration as safe, despite using a method that might otherwise be dangerous, wrap it in a `safety_assured` block.

```ruby
class MySafeMigration < ActiveRecord::Migration[5.2]
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

> Since `remove_column` always requires a `safety_assured` block, it’s not possible to add a custom check for `remove_column` operations

## Existing Migrations

To mark migrations as safe that were created before installing this gem, create an initializer with:

```ruby
StrongMigrations.start_after = 20170101000000
```

Use the version from your latest migration.

## Dangerous Tasks

For safety, dangerous rake tasks are disabled in production - `db:drop`, `db:reset`, `db:schema:load`, and `db:structure:load`. To get around this, use:

```sh
SAFETY_ASSURED=1 rake db:drop
```

## Faster Migrations

Only dump the schema when adding a new migration. If you use Git, create an initializer with:

```ruby
ActiveRecord::Base.dump_schema_after_migration = Rails.env.development? &&
  `git status db/migrate/ --porcelain`.present?
```

## Schema Sanity

Columns can flip order in `db/schema.rb` when you have multiple developers. One way to prevent this is to [alphabetize them](https://www.pgrs.net/2008/03/13/alphabetize-schema-rb-columns/). Add to the end of your `Rakefile`:

```ruby
task "db:schema:dump": "strong_migrations:alphabetize_columns"
```

## Custom Messages

To customize specific messages, create an initializer with:

```ruby
StrongMigrations.error_messages[:add_column_default] = "Your custom instructions"
```

Check the [source code](https://github.com/ankane/strong_migrations/blob/master/lib/strong_migrations.rb) for the list of keys.

## Analyze Tables (Postgres)

Analyze tables automatically (to update planner statistics) after an index is added. Create an initializer with:

```ruby
StrongMigrations.auto_analyze = true
```

## Lock Timeout (Postgres)

It’s a good idea to set a lock timeout for the database user that runs migrations. This way, if migrations can’t acquire a lock in a timely manner, other statements won’t be stuck behind it. Here’s a great explanation of [how lock queues work](https://www.citusdata.com/blog/2018/02/15/when-postgresql-blocks/).

```sql
ALTER ROLE myuser SET lock_timeout = '10s';
```

There’s also [a gem](https://github.com/gocardless/activerecord-safer_migrations) you can use for this.

## Bigint Primary Keys (Postgres & MySQL)

Rails 5.1+ uses `bigint` for primary keys to keep you from running out of ids. To get this in earlier versions of Rails, check out [rails-bigint-primarykey](https://github.com/Shopify/rails-bigint-primarykey).

## Additional Reading

- [Rails Migrations with No Downtime](https://pedro.herokuapp.com/past/2011/7/13/rails_migrations_with_no_downtime/)
- [Safe Operations For High Volume PostgreSQL](https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/)

## Credits

Thanks to Bob Remeika and David Waller for the [original code](https://github.com/foobarfighter/safe-migrations) and [Sean Huber](https://github.com/LendingHome/zero_downtime_migrations) for the bad/good readme format.

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/strong_migrations/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/strong_migrations/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development and testing:

```sh
git clone https://github.com/ankane/strong_migrations.git
cd strong_migrations
bundle install
bundle exec rake test
```
