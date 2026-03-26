require "html-proofer"
require "yaml"

namespace :test do
  desc "Check the built site with html-proofer"
  task :html_proofer do
    abort "❌ No _site/ directory found. Please run 'bundle exec rake build' first." unless Dir.exist?("./_site")

    cfg = OpennewsRakeTasks.configuration

    base_ignore_urls = [
      "http://localhost",
      "http://127.0.0.1",
    ]

    original_verbose = $VERBOSE
    $VERBOSE = nil

    begin
      HTMLProofer.check_directory(
        "./_site",
        {
          disable_external: true,
          enforce_https: true,
          allow_hash_href: true,
          log_level: :error,
          ignore_files: cfg.html_proofer_ignore_files,
          ignore_urls: base_ignore_urls + cfg.html_proofer_ignore_urls,
        },
      ).run
    ensure
      $VERBOSE = original_verbose
    end
  end

  desc "Check common Liquid template issues"
  task :templates do
    errors = []
    warnings = []

    Dir
      .glob("**/*.{html,md}", File::FNM_DOTMATCH)
      .each do |file|
        next if file.start_with?("_site/", ".git/", "vendor/", "node_modules/")
        next if file == "TROUBLESHOOTING.md"

        content = File.read(file)
        lines = content.split("\n")

        lines.each_with_index do |line, idx|
          line_num = idx + 1

          if line =~ /href="\{\{[^}]+\}\}"/ && line !~ /href="\{\{\s*\w+\.\w+.*\}\}"/
            warnings << "#{file}:#{line_num}: Possibly unescaped Liquid in href:\n      #{line.strip}"
          end
        end

        if_count = content.scan(/\{%\s*if\s+/).size
        endif_count = content.scan(/\{%\s*endif\s*%\}/).size
        errors << "#{file}: Mismatched if/endif (#{if_count} if vs #{endif_count} endif)" if if_count != endif_count

        for_count = content.scan(/\{%\s*for\s+/).size
        endfor_count = content.scan(/\{%\s*endfor\s*%\}/).size
        if for_count != endfor_count
          errors << "#{file}: Mismatched for/endfor (#{for_count} for vs #{endfor_count} endfor)"
        end
      end

    if errors.any?
      puts "❌ Template errors:"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    elsif warnings.any?
      puts "⚠️  Template warnings (may be false positives):"
      warnings.each { |w| puts "  - #{w}" }
      puts "\n💡 Review these to ensure Liquid syntax is correct"
    else
      puts "✅ Templates look good"
    end
  end

  desc "Check page-configuration props (permalink/title) in markdown"
  task :page_config do
    errors = []
    warnings = []

    Dir
      .glob("*.md")
      .each do |file|
        next if /^[A-Z]+\.md$/.match?(file)
        next if file == "TROUBLESHOOTING.md"

        content = File.read(file)
        if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
          fm = YAML.safe_load($1)
          warnings << "#{file}: Missing 'permalink' field" unless fm["permalink"]
        else
          errors << "#{file}: No page-config args found"
        end
      end

    if errors.any?
      puts "❌ Page-config errors:"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    elsif warnings.any?
      puts "⚠️  Page-config warnings:"
      warnings.each { |w| puts "  - #{w}" }
    else
      puts "✅ Page-config valid"
    end
  end

  desc "Check for placeholder content in built site"
  task :placeholders do
    placeholders = []

    Dir
      .glob("_site/**/*.html")
      .each do |file|
        content = File.read(file)

        %w[TODO FIXME XXX PLACEHOLDER].each do |placeholder|
          if content.include?(placeholder)
            count = content.scan(/#{Regexp.escape(placeholder)}/).size
            placeholders << "#{file}: Contains '#{placeholder}' (#{count}x)"
          end
        end
      end

    if placeholders.any?
      puts "⚠️  Found placeholder content:"
      placeholders.uniq.each { |p| puts "  - #{p}" }
    else
      puts "✅ No placeholder content found"
    end
  end

  desc "Test for common accessibility issues"
  task :a11y do
    issues = []

    Dir
      .glob("_site/**/*.html")
      .each do |file|
        content = File.read(file)

        content
          .scan(/<img[^>]+>/)
          .each { |img| issues << "#{file}: Image without alt attribute: #{img[0..50]}..." unless img.include?("alt=") }

        issues << "#{file}: Empty heading tag found" if %r{<h[1-6][^>]*>\s*</h[1-6]>}.match?(content)

        issues << "#{file}: Missing lang attribute on <html>" unless /<html[^>]+lang=/.match?(content)

        content
          .scan(/<input[^>]+>/)
          .each do |input|
            next if input.include?('type="hidden"')
            unless input.include?("aria-label=") || input.include?("id=")
              issues << "#{file}: Input without label or aria-label: #{input[0..50]}..."
            end
          end
      end

    if issues.any?
      puts "⚠️  Accessibility issues (#{issues.size}):"
      issues.first(15).each { |i| puts "  - #{i}" }
      puts "  ... and #{issues.size - 15} more" if issues.size > 15
    else
      puts "✅ Basic accessibility tests passed"
    end
  end

  desc "Test for performance issues"
  task :performance do
    warnings = []

    Dir
      .glob("_site/**/*.html")
      .each do |file|
        size = File.size(file)
        warnings << "#{file}: Large HTML file (#{size / 1024}KB)" if size > 200_000

        content = File.read(file)

        inline_styles = content.scan(/<[^>]+style=/).size
        warnings << "#{file}: #{inline_styles} inline style attributes (consider external CSS)" if inline_styles > 10

        warnings << "#{file}: Contains base64-encoded image data (hurts performance)" if content.include?("data:image")
      end

    Dir
      .glob("_site/**/*.css")
      .each do |file|
        size = File.size(file)
        warnings << "#{file}: Large CSS file (#{size / 1024}KB)" if size > 100_000
      end

    if warnings.any?
      puts "⚠️  Performance warnings:"
      warnings.each { |w| puts "  - #{w}" }
    else
      puts "✅ Performance tests passed"
    end
  end
end

desc "Run all tests"
task test: %w[test:html_proofer test:templates test:page_config test:placeholders test:a11y test:performance] do
  puts "\n" + "=" * 60
  puts "✅ All validation tests passed!"
  puts "=" * 60
end
