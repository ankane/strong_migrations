# http://nithinbekal.com/posts/safe-rake-tasks

namespace :strong_migrations do
  task safety_assured: :environment do
    raise "Set SAFETY_ASSURED=1 to run this task in production" if Rails.env.production? && !ENV["SAFETY_ASSURED"]
  end
end

["db:drop", "db:reset", "db:schema:load", "db:structure:load"].each do |t|
  Rake::Task[t].enhance ["strong_migrations:safety_assured"]
end
