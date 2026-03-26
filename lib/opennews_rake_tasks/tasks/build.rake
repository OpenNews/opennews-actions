require "jekyll"

desc "Build the Jekyll site"
task build: :validate_yaml do
  options = {"source" => ".", "destination" => "./_site", "config" => "_config.yml", "quiet" => true}
  begin
    Jekyll::Site.new(Jekyll.configuration(options)).process
    puts "✅ Build complete!"
  rescue => e
    abort "❌ Jekyll build failed: #{e.message}"
  end
end
