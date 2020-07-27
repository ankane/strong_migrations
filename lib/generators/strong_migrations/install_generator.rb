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

      def target_version
        case ActiveRecord::Base.connection_config[:adapter].to_s
        when /mysql/
          # could try to connect to database and check for MariaDB
          # but this should be fine
          '"8.0.12"'
        else
          "10"
        end
      end
    end
  end
end
