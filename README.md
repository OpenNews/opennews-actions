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

