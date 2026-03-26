# opennews-actions

Shared GitHub Actions automation for OpenNews Jekyll/static site repos.

---

> ⚠️ **Changes here affect live websites.**
>
> This repo is a shared dependency for production sites run by OpenNews. Every merge to `main` automatically creates a new release and increments the version tag. Consuming repos that pin to `@v1` will pick up all patch releases within that major version automatically — meaning a bad merge here can break deploys or health checks across multiple live sites.
>
> **Therefore:**
> - **All changes must go through a pull request.** Direct pushes to `main` are not permitted.
> - **Dependabot updates require PR review** before merge — they are not auto-merged.
> - **Merging to `main` triggers an automatic patch release** (e.g. `v1.0.2 → v1.0.3`) via the release workflow.
> - **Breaking changes to action inputs or workflow interfaces** (anything that would require consuming repos to update their workflow files) **must be released as a new major version** (e.g. `v2`). Update the `tag_name` in `.github/workflows/release.yml` and notify consuming repo maintainers before merging.

---

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

Pin to a release tag (`@v1`, `@v1.0.0`) rather than `@main` to avoid unexpected changes. Releases follow [semantic versioning](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions#using-release-management-for-actions).

A floating `@latest` tag is also maintained and always points to the most recent release. Use it only in non-production contexts (local testing, dev repos) — it will automatically follow every patch release without warning.

Every merge to `main` automatically publishes a new patch release via `.github/workflows/release.yml`. Release notes are generated from PR titles, categorized by label (breaking change, enhancement, bug, dependencies).

For breaking changes, manually bump the major version in the release workflow and create the new tag **before** merging, so consuming repos have time to migrate.
