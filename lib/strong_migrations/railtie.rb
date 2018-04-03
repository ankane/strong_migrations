# ensure activerecord tasks are loaded first
require "active_record/railtie"

module StrongMigrations
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/strong_migrations.rake"

      ["db:drop", "db:reset", "db:schema:load", "db:structure:load"].each do |t|
        Rake::Task[t].enhance ["strong_migrations:safety_assured"]
      end
    end
  end
end
