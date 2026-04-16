require_relative "lib/opennews/rake_tasks/version"

Gem::Specification.new do |spec|
  spec.name = "opennews-rake-tasks"
  spec.version = OpenNews::RakeTasks::VERSION
  spec.authors = ["OpenNews"]
  spec.email = ["source@opennews.org"]

  spec.summary = "Shared Rake tasks for OpenNews Jekyll static sites"
  spec.description = <<~DESC
    A collection of reusable Rake tasks covering build, test, review, format,
    and outdated-dependency checks for OpenNews Jekyll-based static sites.
    Tasks that depend on repo-specific configuration (ignore lists, required
    files) are configurable via OpenNews::RakeTasks.configure.
  DESC
  spec.homepage = "https://github.com/OpenNews/opennews-actions"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md",
  ].select { |f| File.file?(f) }

  spec.require_paths = ["lib"]

  spec.add_dependency "rake", "~> 13.0"
  spec.add_dependency "jekyll", "~> 4.3"
  spec.add_dependency "html-proofer", "~> 5.0"
end
