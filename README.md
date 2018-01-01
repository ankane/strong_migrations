# Strong Migrations

Catch unsafe migrations at dev time

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://travis-ci.org/ankane/strong_migrations.svg?branch=master)](https://travis-ci.org/ankane/strong_migrations)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'strong_migrations'
```

## Dangerous Operations

The following operations can cause downtime or errors:

- adding a column with a non-null default value to an existing table
- changing the type of a column
- renaming a table
- renaming a column
- removing a column
- adding an index non-concurrently (Postgres only)
- adding a `json` column to an existing table (Postgres only)

For more info, check out:

- [Rails Migrations with No Downtime](http://pedro.herokuapp.com/past/2011/7/13/rails_migrations_with_no_downtime/)
- [Safe Operations For High Volume PostgreSQL](https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/) (if it’s relevant)

Also checks for best practices:

- keeping indexes to three columns or less

## The Zero Downtime Way

### Adding a column with a default value

1. Add the column without a default value
2. Add the default value
3. Commit the transaction
4. Backfill the column

```ruby
class AddSomeColumnToUsers < ActiveRecord::Migration
  def up
    # 1
    add_column :users, :some_column, :text

    # 2
    change_column_default :users, :some_column, "default_value"

    # 3
    commit_db_transaction

    # 4.a (Rails 5+)
    User.in_batches.update_all some_column: "default_value"

    # 4.b (Rails < 5)
    User.find_in_batches do |users|
      User.where(id: users.map(&:id)).update_all some_column: "default_value"
    end
  end

  def down
    remove_column :users, :some_column
  end
end
```

### Renaming or changing the type of a column

If you really have to:

1. Create a new column
2. Write to both columns
3. Backfill data from the old column to the new column
4. Move reads from the old column to the new column
5. Stop writing to the old column
6. Drop the old column

### Renaming a table

If you really have to:

1. Create a new table
2. Write to both tables
3. Backfill data from the old table to new table
4. Move reads from the old table to the new table
5. Stop writing to the old table
6. Drop the old table

### Removing a column

ActiveRecord caches database columns at runtime. So if you drop a column that ActiveRecord expects, it might cause it to crash when performing other queries until your app reboots. The better strategy is to first tell ActiveRecord to ignore the column, and then once all instances of your app are ignoring the column, drop it.

1. Tell ActiveRecord to ignore the column from its cache (code below)
2. Deploy step 1.
3. Write a migration to remove the column.
4. Deploy step 2.


```ruby
# For Rails 5+
class User < ActiveRecord::Base
  self.ignored_columns = %w(some_column)
end

# For Rails < 5
class User < ActiveRecord::Base
  def self.columns
    super.reject { |c| c.name == "some_column" }
  end
end
```

### Adding an index (Postgres)

Add indexes concurrently.

```ruby
class AddSomeIndexToUsers < ActiveRecord::Migration
  def change
    commit_db_transaction
    add_index :users, :some_index, algorithm: :concurrently
  end
end
```

### Adding a json column (Postgres)

There’s no equality operator for the `json` column type, which causes issues for `SELECT DISTINCT` queries. Replace all calls to `uniq` with a custom scope.

```ruby
scope :uniq_on_id, -> { select("DISTINCT ON (your_table.id) your_table.*") }
```

## Assuring Safety

To mark a step in the migration as safe, despite using method that might otherwise be dangerous, wrap it in a `safety_assured` block.

```ruby
class MySafeMigration < ActiveRecord::Migration
  def change
    safety_assured { remove_column :users, :some_column }
  end
end
```

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

## Analyze Tables (Postgres)

Analyze tables automatically (to update planner statistics) after an index is added. Create an initializer with:

```ruby
StrongMigrations.auto_analyze = true
```

## Lock Timeout (Postgres)

It’s a good idea to set a lock timeout for the database user that runs migrations. This way, if migrations can’t acquire a lock in a timely manner, other statements won’t be stuck behind it.

```sql
ALTER ROLE myuser SET lock_timeout = '10s';
```

## Credits

Thanks to Bob Remeika and David Waller for the [original code](https://github.com/foobarfighter/safe-migrations).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/strong_migrations/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/strong_migrations/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
