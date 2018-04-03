module StrongMigrations
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/strong_migrations.rake"
    end

    initializer "strong_migrations" do
      ["db:drop", "db:reset", "db:schema:load", "db:structure:load"].each do |t|
        Rake::Task[t].enhance ["strong_migrations:safety_assured"]
      end
    end
  end
end
