module OpenNews
  module RakeTasks
    class Configuration
      # Files to ignore during html-proofer internal link checks.
      # Consumer repos may append repo-specific patterns:
      #   OpenNews::RakeTasks.configure { |c| c.html_proofer_ignore_files << %r{blog/} }
      attr_accessor :html_proofer_ignore_files

      # URLs to ignore during html-proofer internal link checks.
      attr_accessor :html_proofer_ignore_urls

      # Files to ignore during review:external_links checks.
      attr_accessor :external_links_ignore_files

      # URLs to ignore during review:external_links checks.
      # The defaults below cover common infrastructure/tracking hosts that
      # are frequently blocked by bot-protection or unreachable from CI.
      attr_accessor :external_links_ignore_urls

      # Required files checked by the `check` task.
      # Override in consumer repos if package.json is not present.
      attr_accessor :required_files

      def initialize
        @html_proofer_ignore_files = []
        @html_proofer_ignore_urls = [
          "http://localhost",
          "http://127.0.0.1",
          /mitrakalita\.com/,
        ]

        @external_links_ignore_files = []
        @external_links_ignore_urls = [
          "http://localhost",
          "http://127.0.0.1",
          "https://use.typekit.net",
          /mitrakalita\.com/,
          /flickr\.com/,
          /medium\.com/,
          /nytimes\.com/,
          /eventbrite\.com/,
          /archive\.org/,
        ]

        @required_files = %w[_config.yml Gemfile package.json]
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      # Yields the configuration object so consumer repos can adjust defaults:
      #
      #   OpenNews::RakeTasks.configure do |config|
      #     config.html_proofer_ignore_urls += [/example\.com/]
      #     config.required_files -= ["package.json"]
      #   end
      def configure
        yield(configuration)
      end
    end
  end
end
