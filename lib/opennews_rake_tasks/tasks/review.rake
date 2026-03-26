require "html-proofer"
require "yaml"
require "fileutils"

module OpennewsRakeTasks
  module Review
    class QuietReporter
      attr_accessor :failures

      def report
        # no-op: condensed summary is printed in rescue handlers
      end
    end

    def self.fetch_url(url)
      require "net/http"
      require "uri"

      uri = URI.parse(url)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)

        raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end
    rescue => e
      raise "Failed to fetch #{url}: #{e.message}"
    end

    def self.normalize_html(content)
      normalized = content.dup

      normalized.gsub!(/\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}/, "TIMESTAMP")
      normalized.gsub!(/\d{1,2}\/\d{1,2}\/\d{4}/, "DATE")
      normalized.gsub!(/session[-_]?id["\s:=]+[a-zA-Z0-9]+/i, "SESSION_ID")
      normalized.gsub!(/[?&]utm_[a-z]+=[^&"'\s]+/, "")
      normalized.gsub!(/\.(css|js|png|jpg|gif|svg)\?v=[a-zA-Z0-9]+/, '.\1')
      normalized.gsub!(/\s+/, " ")
      normalized.strip!

      normalized
    end

    # Default external-link ignore list: universal patterns applicable to all sites.
    # Sites add their own dead links via OpennewsRakeTasks.configure.
    BASE_REVIEW_IGNORE_URLS = [
      "http://localhost",
      "http://127.0.0.1",
      # CDN that blocks automated requests
      "https://use.typekit.net",
      # Sites that commonly block automated link checkers
      /flickr\.com/,
      /medium\.com/,
      /nytimes\.com/,
      /chronicle\.com/,
      /eventbrite\.com/,
      /stanford\.edu/,
      /archive\.org/,
    ].freeze

    def self.print_deduplicated_summary(proofer)
      failures = proofer.failed_checks
      return if failures.empty?

      puts "\n" + "=" * 80
      puts "DEDUPLICATED FAILURE SUMMARY"
      puts "=" * 80

      external_by_status_and_url = Hash.new { |h, k| h[k] = {count: 0, paths: []} }
      non_external = Hash.new(0)

      failures.each do |failure|
        if failure.check_name == "Links > External"
          url = failure.description[/External link\s+(\S+)\s+failed/, 1] || "unknown"
          status = failure.status || failure.description[/status code\s+(\d+)/, 1]&.to_i || 0
          key = [status, url]
          external_by_status_and_url[key][:count] += 1
          if failure.path
            normalized_path = failure.path.sub(%r{\A\./_site}, "")
            normalized_path = normalized_path.sub(%r{/index\.html\z}, "/")
            normalized_path = "/" if normalized_path.empty?
            external_by_status_and_url[key][:paths] << normalized_path
          end
        else
          non_external[failure.check_name] += 1
        end
      end

      if external_by_status_and_url.any?
        puts "\n🌐 External Link Failures: #{external_by_status_and_url.size} unique URLs"

        grouped_by_status = Hash.new { |h, k| h[k] = [] }
        external_by_status_and_url.each do |(status, url), meta|
          unique_paths = meta[:paths].uniq.sort
          grouped_by_status[status] << {
            url: url,
            count: meta[:count],
            unique_paths: unique_paths.size,
            paths: unique_paths,
          }
        end

        {
          0 => "⏱️  Connection Timeouts/Failures",
          403 => "🚫 HTTP 403 Forbidden",
          404 => "🔍 HTTP 404 Not Found",
          410 => "🗑️  HTTP 410 Gone",
          500 => "💥 HTTP 500 Server Error",
          503 => "⚠️  HTTP 503 Service Unavailable",
        }.each do |code, label|
          next unless grouped_by_status[code]&.any?

          entries = grouped_by_status[code].sort_by { |entry| -entry[:count] }
          puts "\n   #{label}: #{entries.size} URLs"
          entries
            .first(8)
            .each do |entry|
              puts "      - #{entry[:url]} (#{entry[:count]}x across #{entry[:unique_paths]} page(s))"
              entry[:paths].first(3).each { |path| puts "        • #{path}" }
              puts "        • ... and #{entry[:paths].size - 3} more page(s)" if entry[:paths].size > 3
            end
          puts "      ... and #{entries.size - 8} more" if entries.size > 8
        end

        other_codes = grouped_by_status.keys - [0, 403, 404, 410, 500, 503]
        puts "\n   Other status codes: #{other_codes.sort.join(", ")}" if other_codes.any?
      end

      if non_external.any?
        puts "\nℹ️  Other failure categories"
        non_external.sort.each { |check_name, count| puts "   - #{check_name}: #{count}" }
      end

      puts "\n" + "=" * 80
      puts "Total unique external URLs: #{external_by_status_and_url.size}"
      puts "Total failure occurrences: #{failures.size}"
      puts "=" * 80 + "\n"
    end
  end
end

namespace :review do
  desc "Check external/public URLs in the built site (slower, requires network access)"
  task :external_links do
    abort "❌ No _site/ directory found. Please run 'bundle exec rake build' first." unless Dir.exist?("./_site")

    cfg = OpennewsRakeTasks.configuration
    proofer = nil

    original_verbose = $VERBOSE
    $VERBOSE = nil

    begin
      puts "🔍 Checking external links (this takes a while)..."
      proofer =
        HTMLProofer.check_directory(
          "./_site",
          {
            disable_external: false,
            enforce_https: false,
            ignore_urls: OpennewsRakeTasks::Review::BASE_REVIEW_IGNORE_URLS + cfg.review_ignore_urls,
            ignore_files: cfg.review_ignore_files,
            allow_hash_href: true,
            check_external_hash: false,
            log_level: :info,
            typhoeus: {
              followlocation: true,
              maxredirs: 5,
              connecttimeout: 10,
              timeout: 30,
            },
            hydra: {
              max_concurrency: 2,
            },
            cache: {
              timeframe: {
                external: "1d",
              },
            },
          },
        )
      proofer.reporter = OpennewsRakeTasks::Review::QuietReporter.new

      proofer.run
      puts "\n✅ External link validation passed!"
    rescue Interrupt
      puts "⚠️  EXTERNAL LINK VALIDATION INTERRUPTED"
      OpennewsRakeTasks::Review.print_deduplicated_summary(proofer) if proofer
      raise
    rescue SystemExit
      puts "❌ EXTERNAL LINK VALIDATION FAILED"
      OpennewsRakeTasks::Review.print_deduplicated_summary(proofer) if proofer
      raise
    rescue => e
      puts "❌ EXTERNAL LINK VALIDATION FAILED: #{e.message}"
      OpennewsRakeTasks::Review.print_deduplicated_summary(proofer) if proofer
      raise
    ensure
      $VERBOSE = original_verbose
    end
  end

  desc "Compare staging vs production site content (requires both sites to be deployed)"
  task :compare_deployed_sites do
    require "net/http"
    require "uri"

    abort "❌ _config.yml not found. Are you in the project root directory?" unless File.exist?("_config.yml")

    begin
      config = YAML.safe_load_file("_config.yml")
      deployment = config["deployment"] || {}
      staging_bucket = deployment["staging_bucket"]
      prod_bucket = deployment["bucket"]
    rescue => e
      abort "❌ Error loading _config.yml: #{e.message}"
    end

    abort "❌ Staging bucket not configured in _config.yml" unless staging_bucket
    abort "❌ Production bucket not configured in _config.yml" unless prod_bucket

    staging_url = "http://#{staging_bucket}".chomp("/")
    prod_url = "https://#{prod_bucket}".chomp("/")

    puts "🔍 Comparing deployed sites:"
    puts "   Staging:    #{staging_url}"
    puts "   Production: #{prod_url}"
    puts ""

    html_files = Dir.glob("_site/**/*.html").map { |f| f.sub("_site", "") }

    extra_paths = []

    extra_paths.concat(ENV["EXTRA_PATHS"].split(",").map(&:strip).reject(&:empty?)) if ENV["EXTRA_PATHS"]

    if ENV["EXTRA_PATHS_FILE"]
      abort "❌ EXTRA_PATHS_FILE not found: #{ENV["EXTRA_PATHS_FILE"]}" unless File.exist?(ENV["EXTRA_PATHS_FILE"])

      file_paths =
        File.readlines(ENV["EXTRA_PATHS_FILE"]).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
      extra_paths.concat(file_paths)
    end

    unless extra_paths.empty?
      extra_paths.map! { |path| path.start_with?("/") ? path : "/#{path}" }
      html_files = (html_files + extra_paths).uniq
      puts "➕ Added #{extra_paths.size} extra path(s) from EXTRA_PATHS/EXTRA_PATHS_FILE"
    end

    differences = []
    errors = []
    checked = 0

    html_files.sort.each do |path|
      staging_page_url = "#{staging_url}#{path}"
      prod_page_url = "#{prod_url}#{path}"

      begin
        staging_content = OpennewsRakeTasks::Review.fetch_url(staging_page_url)
        prod_content = OpennewsRakeTasks::Review.fetch_url(prod_page_url)

        staging_normalized = OpennewsRakeTasks::Review.normalize_html(staging_content)
        prod_normalized = OpennewsRakeTasks::Review.normalize_html(prod_content)

        if staging_normalized != prod_normalized
          differences << path
          puts "⚠️  DIFFERS: #{path}"
        else
          print "."
        end

        checked += 1
      rescue => e
        errors << "#{path}: #{e.message}"
        print "E"
      end
    end

    puts "\n\n" + "=" * 60
    puts "Comparison complete: #{checked} pages checked"
    puts "Differences: #{differences.size}"
    puts "Errors: #{errors.size}"

    if differences.any?
      puts "\n⚠️  Pages with differences:"
      differences.each { |d| puts "  - #{d}" }
    end

    if errors.any?
      puts "\n❌ Pages with errors:"
      errors.each { |e| puts "  - #{e}" }
    end

    puts "=" * 60
  end
end
