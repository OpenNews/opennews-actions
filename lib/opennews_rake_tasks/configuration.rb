module OpennewsRakeTasks
  class Configuration
    # Files that must exist for `rake check` to pass.
    # Override in consuming repos that don't use npm (remove package.json).
    attr_accessor :required_files

    # Extra URLs/patterns to ignore in `rake test:html_proofer`.
    # Merged with the built-in defaults (localhost, 127.0.0.1).
    attr_accessor :html_proofer_ignore_urls

    # Extra file patterns to ignore in `rake test:html_proofer`.
    attr_accessor :html_proofer_ignore_files

    # Extra URLs/patterns to ignore in `rake review:external_links`.
    # Merged with the built-in defaults (localhost, common blocking domains).
    attr_accessor :review_ignore_urls

    # Extra file patterns to ignore in `rake review:external_links`.
    attr_accessor :review_ignore_files

    def initialize
      @required_files = %w[_config.yml Gemfile package.json]
      @html_proofer_ignore_urls = []
      @html_proofer_ignore_files = []
      @review_ignore_urls = []
      @review_ignore_files = []
    end
  end
end
