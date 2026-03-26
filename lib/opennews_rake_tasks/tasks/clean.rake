require "fileutils"

desc "Clean build artifacts"
task :clean do
  puts "🧹 Cleaning build artifacts..."
  FileUtils.rm_rf(%w[_site .jekyll-cache .sass-cache .jekyll-metadata])
  puts "✅ Clean complete!"
end
