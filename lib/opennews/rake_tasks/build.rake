require "jekyll"
require "yaml"
require "psych"
require "fileutils"

# Recursively walk a Psych AST node and collect duplicate mapping keys.
def collect_yaml_duplicate_keys(node, file, errors = [])
  return errors unless node.respond_to?(:children) && node.children

  if node.is_a?(Psych::Nodes::Mapping)
    keys = node.children.each_slice(2).map { |k, _| k.value if k.respond_to?(:value) }.compact
    keys.group_by(&:itself).each { |key, hits| errors << "#{file}: duplicate key '#{key}'" if hits.size > 1 }
  end

  node.children.each { |child| collect_yaml_duplicate_keys(child, file, errors) }
  errors
end

desc "Validate YAML files for syntax errors and duplicate keys"
task :validate_yaml do
  errors = []

  Dir
    .glob("{_config.yml,_data/**/*.{yml,yaml}}")
    .sort
    .each do |file|
      node = Psych.parse_file(file)
      collect_yaml_duplicate_keys(node, file, errors)
      YAML.safe_load_file(file)
    rescue Psych::SyntaxError => e
      errors << "#{file}: syntax error — #{e.message}"
    rescue Psych::DisallowedClass => e
      errors << "#{file}: unsafe YAML — #{e.message}"
    rescue => e
      errors << "#{file}: #{e.message}"
    end

  if errors.any?
    puts "❌ YAML validation errors:"
    errors.each { |e| puts "  - #{e}" }
    abort
  else
    puts "✅ YAML files are valid"
  end
end

desc "Run configuration checks"
task check: :validate_yaml do
  required_files = OpenNews::RakeTasks.configuration.required_files
  missing_files = required_files.reject { |f| File.exist?(f) }

  if missing_files.any?
    puts "❌ Missing required files: #{missing_files.join(", ")}"
    exit 1
  end

  config = YAML.load_file("_config.yml")
  errors = []
  warnings = []

  if config["deployment"]
    deployment = config["deployment"]
    warnings << "deployment.bucket not configured" unless deployment["bucket"]
    warnings << "deployment.staging_bucket not configured" unless deployment["staging_bucket"]
    warnings << "deployment.cloudfront_distribution_id not configured" unless deployment["cloudfront_distribution_id"]
  else
    warnings << "No deployment configuration found in _config.yml"
  end

  if errors.any?
    puts "\n❌ Configuration Errors:"
    errors.each { |e| puts "  - #{e}" }
    exit 1
  end

  if warnings.any?
    puts "\n⚠️  Configuration Warnings:"
    warnings.each { |w| puts "  - #{w}" }
  end

  puts "✅ Configuration checks passed!"
end

desc "Build the Jekyll site"
task build: :validate_yaml do
  options = { "source" => ".", "destination" => "./_site", "config" => "_config.yml", "quiet" => true }
  begin
    Jekyll::Site.new(Jekyll.configuration(options)).process
    puts "✅ Build complete!"
  rescue => e
    abort "❌ Jekyll build failed: #{e.message}"
  end
end

desc "Serve the Jekyll site locally"
task :serve do
  puts "🚀 Starting local Jekyll server..."
  sh "bundle exec jekyll serve --livereload"
end

desc "Clean build artifacts"
task :clean do
  puts "🧹 Cleaning build artifacts..."
  FileUtils.rm_rf(%w[_site .jekyll-cache .sass-cache .jekyll-metadata])
  puts "✅ Clean complete!"
end
