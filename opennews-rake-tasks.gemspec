require_relative "lib/opennews_rake_tasks/version"

Gem::Specification.new do |spec|
  spec.name = "opennews-rake-tasks"
  spec.version = OpennewsRakeTasks::VERSION
  spec.authors = ["OpenNews"]
  spec.summary = "Shared Rake tasks for OpenNews Jekyll static-site repositories"
  spec.description = "Provides validate_yaml, check, build, serve, clean, deploy, test, outdated, format, and review rake tasks for OpenNews Jekyll sites. Consumed as a git-sourced gem from OpenNews/opennews-actions."
  spec.homepage = "https://github.com/OpenNews/opennews-actions"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rake"
  spec.add_dependency "jekyll", "~> 4.3"
  spec.add_dependency "psych"
  spec.add_dependency "html-proofer"
end
