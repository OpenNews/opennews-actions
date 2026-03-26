require "yaml"
require "psych"

module OpennewsRakeTasks
  module ValidateYaml
    def self.collect_duplicate_keys(node, file, errors = [])
      return errors unless node.respond_to?(:children) && node.children

      if node.is_a?(Psych::Nodes::Mapping)
        keys = node.children.each_slice(2).map { |k, _| k.value if k.respond_to?(:value) }.compact
        keys.group_by(&:itself).each { |key, hits| errors << "#{file}: duplicate key '#{key}'" if hits.size > 1 }
      end

      node.children.each { |child| collect_duplicate_keys(child, file, errors) }
      errors
    end
  end
end

desc "Validate YAML files for syntax errors and duplicate keys"
task :validate_yaml do
  errors = []

  Dir
    .glob("{_config.yml,_data/**/*.{yml,yaml}}")
    .sort
    .each do |file|
      node = Psych.parse_file(file)
      OpennewsRakeTasks::ValidateYaml.collect_duplicate_keys(node, file, errors)
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
