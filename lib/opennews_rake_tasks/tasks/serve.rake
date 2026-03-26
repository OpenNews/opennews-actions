desc "Serve the Jekyll site locally"
task :serve do
  puts "🚀 Starting local Jekyll server..."
  sh "bundle exec jekyll serve --livereload"
end
