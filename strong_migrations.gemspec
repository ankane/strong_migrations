
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "strong_migrations/version"

Gem::Specification.new do |spec|
  spec.name          = "strong_migrations"
  spec.version       = StrongMigrations::VERSION
  spec.summary       = "Catch unsafe migrations at dev time"
  spec.homepage      = "https://github.com/ankane/strong_migrations"
  spec.license       = "MIT"

  spec.authors       = ["Andrew Kane", "Bob Remeika", "David Waller"]
  spec.email         = ["andrew@chartkick.com", "bob.remeika@gmail.com"]

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "activerecord", ">= 5"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "pg"
end
