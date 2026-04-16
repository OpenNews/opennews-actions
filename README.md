# OpenNews Shared Actions

Centralized GitHub Actions for OpenNews Jekyll sites. Instead of copying the same build, test, and deploy logic across multiple repos, this provides reusable workflows that all OpenNews sites can reference.

## Why this exists

**Problem:** OpenNews maintains multiple Jekyll websites. Previously, each had duplicate GitHub Actions workflows, Rake tasks, and config files. Updates meant changing multiple repos as we found Dependabot upgrades or other efficiencies.

**Solution:** This repo provides shared workflows that consuming repos reference with a single line. Update here once → deployed everywhere automatically.

## ⚠️ Important

**Changes here affect live production websites.** Every merge to `main` auto-releases and deploys to all consuming sites via the floating `@v1` tag. See [SECURITY.md](SECURITY.md) for contribution guidelines and security policies.

## Contents

**For consuming repos:**

| Path | Type | Purpose |
|---|---|---|
| `jekyll-build/action.yml` | Composite Action | Checkout, setup Ruby, validate YAML, run checks, build Jekyll, run tests |
| `.github/workflows/jekyll-deploy.yml` | Reusable Workflow | Build, deploy to S3, invalidate CloudFront, update GitHub Deployment status |
| `.github/workflows/jekyll-health-check.yml` | Reusable Workflow | Build check + open a GitHub Issue on failure |

**Housekeeping (for this repo only):**

| Path | Type | Purpose |
|---|---|---|
| `.github/workflows/codeql.yml` | Internal Workflow | CodeQL security scanning for GitHub Actions (requires `ENABLE_CODEQL_ADVANCED` variable) |
| `.github/workflows/dependency-review.yml` | Internal Workflow | Blocks PRs with vulnerable or restricted-license dependencies |
| `.github/workflows/release.yml` | Internal Workflow | Auto-creates patch releases and updates floating tags on merge to `main` |


## Repository Configuration

**Advanced CodeQL scanning is enabled**  
The CodeQL workflow is enabled by default to avoid conflicts with GitHub's default code scanning. It depends on an Actions Variable -- `ENABLE_CODEQL_ADVANCED: true` -- set in the repo [Settings → Secrets and variables → Actions → Variables](https://github.com/OpenNews/opennews-actions/settings/variables/actions)


## Usage

### `jekyll-build` composite action

Call from any job step in a consuming repo:

```yaml
- name: Build & test
  uses: OpenNews/opennews-actions/jekyll-build@v1
  with:
    run-checks: true   # default: true — runs `bundle exec rake check`
    run-tests: true    # default: true — runs `bundle exec rake test`
```

The consuming repo must have:
- A `.ruby-version` file
- A `Gemfile` with Jekyll and required gems
- `bundle exec rake validate_yaml`, `rake check`, `rake build`, and `rake test` tasks defined

### `jekyll-deploy` reusable workflow

```yaml
# .github/workflows/deploy.yml in a consuming repo
name: Deploy

on:
  push:
    branches: [main, staging]

jobs:
  deploy:
    uses: OpenNews/opennews-actions/.github/workflows/jekyll-deploy.yml@v1
    with:
      environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
      production-url: https://example.opennews.org  # optional
      aws-region: us-east-1                          # optional, default: us-east-1
      run-checks: true                               # optional, default: true
      run-tests: true                                # optional, default: true
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

The consuming repo's `_config.yml` must include a `deployment` block:

```yaml
deployment:
  bucket: my-production-bucket
  staging_bucket: my-staging-bucket
  cloudfront_distribution_id: ABCDEF123456  # optional; omit to skip invalidation
```

### `jekyll-health-check` reusable workflow

```yaml
# .github/workflows/health-check.yml in a consuming repo
name: Health Check

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9am UTC — set your own schedule
  workflow_dispatch:

jobs:
  health-check:
    uses: OpenNews/opennews-actions/.github/workflows/jekyll-health-check.yml@v1
    with:
      issue-labels: automated,health-check,bug  # optional, these are the defaults
```

On failure, the workflow opens a GitHub Issue in the consuming repo (skipping creation if an open issue with the same labels already exists). The schedule trigger must be defined in the consuming repo's workflow — it cannot live in a reusable workflow.

## Versions

**For consuming repos:** Use `@v1` (auto-updates) or pin to specific versions like `@v1.0.3` (manual updates only).

**For contributors:** See [SECURITY.md](SECURITY.md) for release process, testing requirements, and security policies.
