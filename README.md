# opennews-actions

Shared GitHub Actions automation for OpenNews Jekyll/static site repos.

> **Note:** This repo provides only composite actions and reusable workflow YAML. It does not contain shared Ruby code, Rake tasks, or Gems. Ruby/Rake logic lives in each consuming repo's own `Rakefile` and `tasks/` directory.

## Contents

| Path | Type | Purpose |
|---|---|---|
| `jekyll-build/action.yml` | Composite Action | Checkout, setup Ruby, validate YAML, run checks, build Jekyll, run tests |
| `.github/workflows/jekyll-deploy.yml` | Reusable Workflow | Build, deploy to S3, invalidate CloudFront, update GitHub Deployment status |
| `.github/workflows/jekyll-health-check.yml` | Reusable Workflow | Build check + open a GitHub Issue on failure |

---

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

---

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

---

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

---

## Versioning

Pin to a release tag (`@v1`, `@v1.0.0`) rather than `@main` to avoid unexpected changes. Releases follow semantic versioning.
