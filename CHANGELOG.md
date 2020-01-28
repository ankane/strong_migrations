## 0.6.1 (2020-01-28)

- Fixed timeouts for PostgreSQL

## 0.6.0 (2020-01-24)

- Added `statement_timeout` and `lock_timeout`
- Adding a column with a non-null default value is safe in MySQL 8.0.12+ and MariaDB 10.3.2+
- Added `change_column_null` check for MySQL and MariaDB
- Added `auto_analyze` for MySQL and MariaDB
- Added `target_mysql_version` and `target_mariadb_version`
- Switched to `up` for backfilling

## 0.5.1 (2019-12-17)

- Fixed migration name in error messages

## 0.5.0 (2019-12-05)

- Added ability to disable checks
- Added Postgres-specific check for `change_column_null`
- Added optional remove index check

## 0.4.2 (2019-10-27)

- Allow `add_reference` with concurrent indexes

## 0.4.1 (2019-07-12)

- Added `target_postgresql_version`
- Added `unscoped` to backfill instructions

## 0.4.0 (2019-05-27)

- Added check for `add_foreign_key`
- Fixed instructions for adding default value with NOT NULL constraint
- Removed support for Rails 4.2

## 0.3.1 (2018-10-18)

- Fixed error with `remove_column` and `type` argument
- Improved message customization

## 0.3.0 (2018-10-15)

- Added support for custom checks
- Adding a column with a non-null default value is safe in Postgres 11+
- Added checks for `add_belongs_to`, `remove_belongs_to`, `remove_columns`, and `remove_reference`
- Customized messages

## 0.2.3 (2018-07-22)

- Added check for `change_column_null`
- Added support for alphabetize columns with Makara
- Fixed migration reversibility with `auto_analyze`

## 0.2.2 (2018-02-14)

- Friendlier output
- Better method of hooking into ActiveRecord

## 0.2.1 (2018-02-07)

- Recommend `disable_ddl_transaction!` over `commit_db_transaction`
- Suggest `jsonb` over `json` in Postgres 9.4+
- Changing `varchar` to `text` is safe in Postgres 9.1+
- Do not check number of columns for unique indexes

## 0.2.0 (2018-01-07)

- Added customizable error messages
- Updated instructions for adding a column with a default value

## 0.1.9 (2017-06-14)

- Added `start_after` option

## 0.1.8 (2017-05-31)

- Fixed error with `create_table`
- Added check for executing arbitrary SQL

## 0.1.7 (2017-05-29)

- Added check for `force` option with `create_table`
- Added `auto_analyze` option

## 0.1.6 (2017-03-23)

- Adding an index to a newly created table is now safe

## 0.1.5 (2016-07-23)

- Fixed error with Ruby 2.3 frozen strings

## 0.1.4 (2016-03-22)

- Added alphabetize columns

## 0.1.3 (2016-03-12)

- Disabled dangerous rake tasks in production
- Added ability to use `SAFETY_ASSURED` env var

## 0.1.2 (2016-02-24)

- Skip checks on down migrations and rollbacks
- Added check for indexes with more than 3 columns

## 0.1.1 (2015-11-29)

- Fixed `add_index` check for MySQL

## 0.1.0 (2015-11-22)

- First release
