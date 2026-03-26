# opennews-actions

Centralized GitHub Actions automation for OpenNews Jekyll static-site repositories. This public repo provides one composite action and two reusable workflows consumed by all upgraded OpenNews Jekyll repos (`opennews-website`, `srccon`, `srccon-2026`, `srccon-site-starterkit`).

## Automation units

### 1. `jekyll-build` — Composite Action

Handles checkout, Ruby setup, YAML validation, optional configuration checks, Jekyll build, and optional tests. Called as a step (`uses:`) inside any job.

```yaml
- name: Build Jekyll site
  uses: OpenNews/opennews-actions/jekyll-build@v1
  with:
    run-checks: "true"   # optional, default "true" — runs bundle exec rake check
    run-tests: "true"    # optional, default "true" — runs bundle exec rake test
```

**Step sequence:** `actions/checkout@v6` → `ruby/setup-ruby@v1` → `rake validate_yaml` → `rake check` (if `run-checks`) → `rake build` → `rake test` (if `run-tests`)

---

### 2. `.github/workflows/jekyll-deploy.yml` — Reusable Deploy Workflow

Handles the full deploy pipeline: build → extract S3/CloudFront config → authenticate AWS via OIDC → create GitHub Deployment → S3 sync → optional CloudFront invalidation → update Deployment status.

**Inputs:**

| Input | Type | Required | Default | Description |
|---|---|---|---|---|
| `environment` | string | ✅ | — | `staging` or `production` |
| `production-url` | string | | `""` | Canonical URL shown in Deployment status for production (e.g. `https://opennews.org`) |
| `aws-region` | string | | `us-east-1` | AWS region |
| `run-checks` | boolean | | `true` | Run `rake check` |
| `run-tests` | boolean | | `true` | Run `rake test` |

**Secrets:** `AWS_ROLE_ARN` (required) — IAM role for OIDC authentication.

**Calling repo `deploy.yml` example:**

```yaml
name: Deploy to S3

on:
  push:
    branches:
      - main
      - staging

jobs:
  deploy:
    uses: OpenNews/opennews-actions/.github/workflows/jekyll-deploy.yml@v1
    with:
      environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
      production-url: "https://opennews.org"
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

---

### 3. `.github/workflows/jekyll-health-check.yml` — Reusable Health-Check Workflow

Builds the site (without checks or tests), validates the build output, and opens a GitHub Issue if anything fails. The `schedule:` trigger **must live in the calling repo's workflow** — it cannot be defined here.

**Inputs:**

| Input | Type | Required | Default | Description |
|---|---|---|---|---|
| `issue-labels` | string | | `automated,health-check,bug` | Comma-separated labels for the failure issue |

**Calling repo `health-check.yml` example:**

```yaml
name: Weekly Health Check

on:
  schedule:
    - cron: "0 12 * * 1"  # Every Monday at noon UTC
  workflow_dispatch:

jobs:
  health-check:
    uses: OpenNews/opennews-actions/.github/workflows/jekyll-health-check.yml@v1
    with:
      issue-labels: "automated,health-check,bug"
```

> **Note:** The `schedule:` trigger must be defined in the consuming repo's workflow file. Reusable workflows called via `workflow_call` do not fire on `schedule:` events from the called workflow — only `workflow_call` is supported as a trigger here.

---

## `_config.yml` deployment block

The `jekyll-deploy` workflow reads S3 and CloudFront config from a `deployment:` key in the calling repo's `_config.yml`:

```yaml
deployment:
  bucket: my-site.example.org          # production S3 bucket
  staging_bucket: staging.example.org  # staging S3 bucket
  cloudfront_distribution_id: EXXXXXX  # optional; CloudFront invalidation on production only
```

## Pinning to a version

All consuming repos should pin to the `@v1` tag (or a specific `@v1.x.x` tag) rather than `@main` to avoid unexpected breakage:

```yaml
uses: OpenNews/opennews-actions/jekyll-build@v1
uses: OpenNews/opennews-actions/.github/workflows/jekyll-deploy.yml@v1
uses: OpenNews/opennews-actions/.github/workflows/jekyll-health-check.yml@v1
```

---

## `opennews-rake-tasks` gem

This repo also ships a Ruby gem — `opennews-rake-tasks` — that provides the shared Rake tasks called by the composite action (`validate_yaml`, `check`, `build`, `serve`, `clean`, `deploy:*`, `test:*`, `outdated:*`, `format:*`, `review:*`). Consuming repos add it as a git-sourced gem and replace their duplicated `Rakefile` + `tasks/` directories with a minimal configuration.

### Available tasks

| Task | Description |
|---|---|
| `rake validate_yaml` | Validate `_config.yml` and `_data/**/*.{yml,yaml}` for syntax errors and duplicate keys |
| `rake check` | Verify required files exist and `_config.yml` has a `deployment:` block |
| `rake build` | Build the Jekyll site to `_site/` |
| `rake serve` | Start Jekyll with live-reload for local development |
| `rake clean` | Remove `_site/`, `.jekyll-cache/`, `.sass-cache/`, `.jekyll-metadata` |
| `rake test` | Run all validation tests (html-proofer, templates, page config, placeholders, a11y, performance) |
| `rake test:html_proofer` | HTMLProofer on `_site/` (internal links only) |
| `rake test:templates` | Check for Liquid `if`/`endif` mismatches and other template issues |
| `rake test:page_config` | Validate frontmatter (`permalink`) in root-level Markdown files |
| `rake test:placeholders` | Check for TODO/FIXME/XXX in built HTML |
| `rake test:a11y` | Basic accessibility checks (alt text, lang attribute, empty headings) |
| `rake test:performance` | Flag large HTML/CSS files and base64-embedded images |
| `rake outdated` | Check directly-used outdated gems |
| `rake outdated:all` | Check all outdated gems including transitive dependencies |
| `rake lint` | Check Ruby (StandardRB) and other files (Prettier) |
| `rake format` | Auto-fix Ruby and other file formatting |
| `rake review:external_links` | Check all external URLs in `_site/` (slow, requires network) |
| `rake review:compare_deployed_sites` | Diff staging vs production content via HTTP |
| `rake deploy:staging` | Dry-run S3 sync to staging bucket |
| `rake deploy:staging:real` | Interactive real deploy to staging |
| `rake deploy:production` | Dry-run S3 sync to production bucket |
| `rake deploy:production:real` | Interactive real deploy to production with CloudFront invalidation |

### Adding the gem to a consuming repo

**`Gemfile`** — add a git-sourced entry pointing to this repo:

```ruby
source "https://rubygems.org"

gem "jekyll", "~> 4.3"
gem "jekyll-redirect-from"
gem "opennews-rake-tasks", github: "OpenNews/opennews-actions", tag: "v1"

group :development do
  gem "standard", require: false
end
```

> Bundler fetches the gem directly from GitHub at the pinned tag. No RubyGems publishing required.

**`Rakefile`** — replace the duplicated file with this minimal version:

```ruby
require "jekyll"
require "yaml"
require "psych"
require "fileutils"
require "opennews_rake_tasks"

OpennewsRakeTasks.configure do |config|
  # Files that must exist for `rake check` (remove package.json if repo has no npm)
  config.required_files = %w[_config.yml Gemfile package.json]

  # Site-specific URLs/patterns to skip in `rake test:html_proofer`
  config.html_proofer_ignore_urls << /my-dead-domain\.example\.com/

  # Site-specific URLs/patterns to skip in `rake review:external_links`
  config.review_ignore_urls << /another-dead-domain\.example\.com/
end

OpennewsRakeTasks.load_tasks

# Load any local task additions/overrides from tasks/ (optional)
Dir.glob("tasks/*.rake").each { |r| load r }

task default: %i[validate_yaml check build]
```

All configuration values are read at task-execution time, so `configure` can appear anywhere before the task is invoked. If `tasks/*.rake` exists in the consuming repo it loads after the shared tasks, allowing additions or overrides.

### Configuration reference

| Option | Type | Default | Description |
|---|---|---|---|
| `required_files` | `Array<String>` | `["_config.yml", "Gemfile", "package.json"]` | Files checked by `rake check`. Set to `%w[_config.yml Gemfile]` for repos without npm. |
| `html_proofer_ignore_urls` | `Array<String\|Regexp>` | `[]` | Extra URLs/patterns to skip in `test:html_proofer`. Merged with built-in defaults (localhost, 127.0.0.1). |
| `html_proofer_ignore_files` | `Array<String\|Regexp>` | `[]` | Extra file paths to skip in `test:html_proofer`. |
| `review_ignore_urls` | `Array<String\|Regexp>` | `[]` | Extra URLs/patterns to skip in `review:external_links`. Merged with built-in defaults (localhost, typekit, common blocking domains). |
| `review_ignore_files` | `Array<String\|Regexp>` | `[]` | Extra file patterns to skip in `review:external_links`. |

