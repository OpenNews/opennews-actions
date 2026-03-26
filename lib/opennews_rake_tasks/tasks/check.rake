require "yaml"

desc "Run configuration checks"
task check: :validate_yaml do
  config_values = OpennewsRakeTasks.configuration
  missing_files = config_values.required_files.reject { |f| File.exist?(f) }

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
