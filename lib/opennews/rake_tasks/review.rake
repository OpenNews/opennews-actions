require "html-proofer"
require "yaml"
require "fileutils"

# Helper module for review tasks — avoids polluting global scope.
module ReviewHelpers
  class QuietReporter
    attr_accessor :failures

    def report
      # no-op: condensed summary is printed in rescue handlers below
    end
  end

  def self.fetch_url(url)
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
end

namespace :review do
  desc "Check external/public URLs in the built site (slower, requires network access)"
  task :external_links do
    abort "❌ No _site/ directory found. Please run 'bundle exec rake build' first." unless Dir.exist?("./_site")

    proofer = nil
    original_verbose = $VERBOSE
    $VERBOSE = nil

    cfg = OpenNews::RakeTasks.configuration

    begin
      puts "🔍 Checking external links (this takes a while)..."
      proofer =
        HTMLProofer.check_directory(
          "./_site",
          {
            disable_external: false,
            enforce_https: false,
            ignore_urls: cfg.external_links_ignore_urls,
            ignore_files: cfg.external_links_ignore_files,
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
      proofer.reporter = ReviewHelpers::QuietReporter.new

      proofer.run
      puts "\n✅ External link validation passed!"
    rescue Interrupt
      puts "⚠️  EXTERNAL LINK VALIDATION INTERRUPTED"
      review_print_deduplicated_summary(proofer) if proofer
      raise
    rescue SystemExit
      puts "❌ EXTERNAL LINK VALIDATION FAILED"
      review_print_deduplicated_summary(proofer) if proofer
      raise
    rescue => _e
      puts "❌ EXTERNAL LINK VALIDATION FAILED"
      review_print_deduplicated_summary(proofer) if proofer
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

    abort "❌ No HTML files found in _site/. Please run 'bundle exec rake build' first." if html_files.empty?

    puts "📄 Found #{html_files.size} pages to compare"
    puts ""

    differences = []
    errors = []
    checked = 0

    html_files.each do |path|
      checked += 1
      print "\rChecking #{checked}/#{html_files.size}..." if checked % 10 == 0

      begin
        staging_content = ReviewHelpers.fetch_url("#{staging_url}#{path}")
        prod_content = ReviewHelpers.fetch_url("#{prod_url}#{path}")

        staging_normalized = ReviewHelpers.normalize_html(staging_content)
        prod_normalized = ReviewHelpers.normalize_html(prod_content)

        if staging_normalized != prod_normalized
          staging_size = staging_normalized.length
          prod_size = prod_normalized.length
          size_diff_pct = ((staging_size - prod_size).abs.to_f / [staging_size, prod_size].max * 100).round(1)
          differences << { path: path, staging_size: staging_size, prod_size: prod_size, size_diff_pct: size_diff_pct }
        end
      rescue => e
        errors << "#{path}: #{e.message}"
      end
    end

    puts "\n✓ Checked #{checked} pages"

    if errors.any?
      puts "⚠️  Errors encountered (#{errors.size}):"
      errors.first(10).each { |e| puts "  - #{e}" }
      puts "  ... and #{errors.size - 10} more" if errors.size > 10
    end

    if differences.any?
      puts "\n 📊 Content differences found (#{differences.size} pages):"

      significant = differences.select { |d| d[:size_diff_pct] > 10 }
      if significant.any?
        puts "⚠️  SIGNIFICANT differences (>10% size change):"
        significant
          .first(20)
          .each do |diff|
            puts "  - #{diff[:path]}"
            puts "    Staging: #{diff[:staging_size]} chars | Production: #{diff[:prod_size]} chars | Diff: #{diff[:size_diff_pct]}%"
          end
        puts "  ... and #{significant.size - 20} more" if significant.size > 20
        puts ""
      end

      minor = differences.select { |d| d[:size_diff_pct] <= 10 }
      if minor.any?
        puts "ℹ️  Minor differences (≤10% size change): #{minor.size} pages"
        minor.each { |diff| puts "  - #{diff[:path]} (#{diff[:size_diff_pct]}% diff)" } if minor.size <= 10
        puts ""
      end

      puts "\n💡 Review these differences to ensure staging changes are intentional before promoting to production."
    else
      puts "✅ No content differences detected between staging and production!"
    end
  end
end

# Helper method — defined at file scope so it is visible from within the
# rescue blocks of the review:external_links task defined above.
def review_print_deduplicated_summary(proofer)
  failures = proofer.failed_checks
  return if failures.empty?

  puts "\n" + "=" * 80
  puts "DEDUPLICATED FAILURE SUMMARY"
  puts "=" * 80

  external_by_status_and_url = Hash.new { |h, k| h[k] = { count: 0, paths: [] } }
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
