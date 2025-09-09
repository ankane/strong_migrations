namespace :strong_migrations do
  # https://www.pgrs.net/2008/03/12/alphabetize-schema-rb-columns/
  desc "Alphabetize columns in db/schema.rb"
  task :alphabetize_columns do
    $stderr.puts "Dumping schema"
    ActiveRecord::Base.logger.level = Logger::INFO

    StrongMigrations.alphabetize_schema = true
  end

  desc "Check pending migrations for strong_migrations violations"
  task check: :environment do
    StrongMigrations.check_pending_migrations
  end

end

