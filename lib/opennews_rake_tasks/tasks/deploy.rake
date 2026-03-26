require "yaml"

module OpennewsRakeTasks
  module Deploy
    S3_ARGS = "--delete --cache-control 'public, max-age=3600'"

    def self.config
      abort "❌ _config.yml not found. Are you in the project root directory?" unless File.exist?("_config.yml")

      begin
        config = YAML.safe_load_file("_config.yml")
        config["deployment"] || {}
      rescue => e
        abort "❌ Error loading _config.yml: #{e.message}"
      end
    end
  end
end

desc "MOSTLY used by GitHub Actions on push/merges to `main` and `staging` branches"
namespace :deploy do
  desc "Run all pre-deployment checks"
  task precheck: %i[check build test] do
    puts "\n✅ All pre-deployment checks passed!"
    puts "\nDeploy with:"
    puts "  rake deploy:staging          # Dry-run to staging"
    puts "  rake deploy:staging:real     # Actually deploy to staging"
    puts "  rake deploy:production       # Dry-run to production"
    puts "  rake deploy:production:real  # Actually deploy to production"
  end

  desc "Deploy to staging (dry-run by default)"
  namespace :staging do
    task default: :dryrun

    desc "Dry-run staging deploy"
    task dryrun: :build do
      config = OpennewsRakeTasks::Deploy.config
      staging_bucket = config["staging_bucket"]
      abort "❌ Staging bucket not configured in _config.yml deployment section" unless staging_bucket

      puts "[DRY RUN] Deploying to staging bucket: #{staging_bucket}..."
      sh "aws s3 sync _site/ s3://#{staging_bucket}/ --dryrun #{OpennewsRakeTasks::Deploy::S3_ARGS}"
      puts "\n✅ Dry-run complete. To deploy for real, run: rake deploy:staging:real"
    end

    desc "Real staging deploy (with confirmation)"
    task real: :build do
      config = OpennewsRakeTasks::Deploy.config
      staging_bucket = config["staging_bucket"]
      abort "❌ Staging bucket not configured in _config.yml deployment section" unless staging_bucket

      puts "⚠️  Deploying to STAGING: #{staging_bucket}"
      print "Continue? (y/N) "

      response = $stdin.gets.chomp
      abort "Deployment cancelled" unless response.downcase == "y"

      puts "Deploying to staging bucket: #{staging_bucket}..."
      sh "aws s3 sync _site/ s3://#{staging_bucket}/ #{OpennewsRakeTasks::Deploy::S3_ARGS}"
      puts "\n✅ Successfully deployed to staging!"
    end
  end

  desc "Deploy to production (dry-run by default)"
  namespace :production do
    task default: :dryrun

    desc "Dry-run production deploy"
    task dryrun: :build do
      config = OpennewsRakeTasks::Deploy.config
      prod_bucket = config["bucket"]
      cloudfront_dist = config["cloudfront_distribution_id"]
      abort "❌ Production bucket not configured in _config.yml deployment section" unless prod_bucket

      puts "[DRY RUN] Deploying to production bucket: #{prod_bucket}..."
      sh "aws s3 sync _site/ s3://#{prod_bucket}/ --dryrun #{OpennewsRakeTasks::Deploy::S3_ARGS}"

      if cloudfront_dist && !cloudfront_dist.empty?
        puts "\n[DRY RUN] Would invalidate CloudFront: #{cloudfront_dist}"
      else
        puts "\n⚠️  No CloudFront distribution configured (cache won't be invalidated)"
      end

      puts "\n✅ Dry-run complete. To deploy for real, run: rake deploy:production:real"
    end

    desc "Real production deploy (with confirmation)"
    task real: :build do
      config = OpennewsRakeTasks::Deploy.config
      prod_bucket = config["bucket"]
      cloudfront_dist = config["cloudfront_distribution_id"]
      abort "❌ Production bucket not configured in _config.yml deployment section" unless prod_bucket

      puts "🚨 DEPLOYING TO PRODUCTION: #{prod_bucket}"
      print "Are you absolutely sure? (yes/N) "
      response = $stdin.gets.chomp
      abort "Deployment cancelled" unless response == "yes"

      puts "\nDeploying to production bucket: #{prod_bucket}..."
      sh "aws s3 sync _site/ s3://#{prod_bucket}/ #{OpennewsRakeTasks::Deploy::S3_ARGS}"

      if cloudfront_dist && !cloudfront_dist.empty?
        puts "\nInvalidating CloudFront distribution: #{cloudfront_dist}..."
        sh "aws cloudfront create-invalidation --distribution-id #{cloudfront_dist} --paths '/*'"
        puts "\n✅ CloudFront cache invalidated"
      else
        puts "\n⚠️  Skipping CloudFront invalidation (not configured)"
      end

      puts "\n🎉 Successfully deployed to production!"
    end
  end
end
