# http://nithinbekal.com/posts/safe-rake-tasks

namespace :strong_migrations do
  task safety_assured: :environment do
    raise "Set SAFETY_ASSURED=1 to run this task in production" if Rails.env.production? && !ENV["SAFETY_ASSURED"]
  end

  # https://www.pgrs.net/2008/03/13/alphabetize-schema-rb-columns/
  task :alphabetize_columns do
    $stderr.puts "Dumping schema"
    ActiveRecord::Base.logger.level = Logger::INFO

    require "strong_migrations/alphabetize_columns"
    ActiveRecord::Base.connection.class.prepend StrongMigrations::AlphabetizeColumns
    if ActiveRecord::ConnectionAdapters.const_defined?('PostGISAdapter')
      ActiveRecord::ConnectionAdapters::PostGISAdapter.prepend StrongMigrations::AlphabetizeColumns
    end
    ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend StrongMigrations::AlphabetizeColumns
  end
end
