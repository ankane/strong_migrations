require_relative "lib/strong_migrations/version"

Gem::Specification.new do |spec|
  spec.name          = "strong_migrations"
  spec.version       = StrongMigrations::VERSION
  spec.summary       = "Catch unsafe migrations in development"
  spec.homepage      = "https://github.com/ankane/strong_migrations"
  spec.license       = "MIT"

  spec.authors       = ["Andrew Kane", "Bob Remeika", "David Waller"]
  spec.email         = ["andrew@ankane.org", "bob.remeika@gmail.com"]

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/#{spec.name}/#{spec.version}"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"

  spec.add_dependency "activerecord", ">= 7.2"
end
