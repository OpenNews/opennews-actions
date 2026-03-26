require_relative "opennews_rake_tasks/version"
require_relative "opennews_rake_tasks/configuration"

module OpennewsRakeTasks
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def load_tasks
      Dir[File.join(__dir__, "opennews_rake_tasks/tasks/*.rake")].sort.each { |f| load f }
    end
  end
end
