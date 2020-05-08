require "rails/generators"

module StrongMigrations
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.join(__dir__, "templates")

      def create_initializer
        template "initializer.rb", "config/initializers/strong_migrations.rb"
      end

      def start_after
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end
    end
  end
end
