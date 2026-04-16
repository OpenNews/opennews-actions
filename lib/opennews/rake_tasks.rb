require "opennews/rake_tasks/version"
require "opennews/rake_tasks/configuration"

module OpenNews
  module RakeTasks
    # Load all .rake files bundled with the gem.
    def self.load_tasks
      Dir.glob(File.join(__dir__, "rake_tasks", "*.rake")).sort.each { |f| load f }
    end
  end
end

# Auto-load tasks when this file is required (the common Rakefile pattern).
OpenNews::RakeTasks.load_tasks
