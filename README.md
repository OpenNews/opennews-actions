# OpenNews Shared Repo Actions

Shared GitHub Actions functionality for OpenNews Jekyll/static site repos. This helps upgrade these without running around a half-dozen sites, e.g. Dependabot.

---

⚠️ **Changes here affect live websites.**  
This repo is a shared dependency for public sites run by OpenNews. Every merge to `main` automatically creates a new release and increments the version tag.

The `v1` tag is **floating** — after every merge, the release workflow force-updates it to point at the new patch release. Consuming repos that reference `@v1` receive every patch automatically with no changes on their end, and they cannot opt out without pinning to a specific tag like `@v1.0.3`. A bad merge here immediately breaks deploys or health checks across all of them.  
PLEASE BE CAREFUL.

---

Since errors are impactful, here are the requirements:

- **All changes must go through a pull request.** Direct pushes to `main` are blocked by branch protection rules, configurable at [Settings → Branches](https://github.com/OpenNews/opennews-actions/settings/branches) in this repo.
- **Dependabot updates require PR review** before merge, and ask AI/Copilot about impacts of the upgrades before merging & creating a new version here.
- **Merging to `main` triggers an automatic patch release** (e.g. `v1.0.2 → v1.0.3`) via the release workflow.
- **Breaking changes to action inputs or workflow interfaces** (anything that would require consuming repos to update their workflow files) **must be released as a new major version** (e.g. `v2`). Coordinate creating a new major release tag (for example, `v2.0.0` and the corresponding `v2` major tag) and checking individual sites on staging _before_ merging.

---

## Testing changes

Before merging a PR, test against a consuming repo by temporarily pointing its workflow file at your branch:

```yaml
# composite action
uses: OpenNews/opennews-actions/jekyll-build@your-branch-name

# reusable workflow
uses: OpenNews/opennews-actions/.github/workflows/jekyll-deploy.yml@your-branch-name
```

Push that change to a branch on the consuming repo, then trigger the workflow manually from the **Actions** tab via "Run workflow." Confirm it passes, then revert or delete that branch.

For **Dependabot PRs**, check the release notes for the updated action (linked from the PR) and ask Copilot whether the upgrade introduces any breaking or behavioral changes before approving.

---

## Contents

| Path | Type | Purpose |
|---|---|---|
| `jekyll-build/action.yml` | Composite Action | Checkout, setup Ruby, validate YAML, run checks, build Jekyll, run tests |
| `.github/workflows/jekyll-deploy.yml` | Reusable Workflow | Build, deploy to S3, invalidate CloudFront, update GitHub Deployment status |
| `.github/workflows/jekyll-health-check.yml` | Reusable Workflow | Build check + open a GitHub Issue on failure |
| `opennews-rake-tasks.gemspec` | Ruby gem | Shared Rake tasks for local development and CI |

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

For breaking changes, manually bump the major version by creating and push the tag via git. This is the only way to break out of the auto-versioning count to a v2 or v3 or wherever you are.

---

## `opennews-rake-tasks` gem

Shared Rake tasks for local development and CI across all OpenNews Jekyll static sites. Load them with one line in your `Rakefile` instead of copying task files from repo to repo.

### What's included

| Task | Description |
|---|---|
| `validate_yaml` | Syntax + duplicate-key check on `_config.yml` and `_data/**/*.{yml,yaml}` |
| `check` | Validates required files and warns on missing deployment config |
| `build` | Runs a Jekyll build into `_site/` |
| `serve` | Starts `jekyll serve --livereload` |
| `clean` | Removes `_site/`, `.jekyll-cache`, `.sass-cache`, `.jekyll-metadata` |
| `test` | Runs all sub-tasks below |
| `test:html_proofer` | Internal link + HTTPS check via html-proofer |
| `test:templates` | Lint Liquid `if`/`for` balance and href escaping |
| `test:page_config` | Checks `permalink` front-matter in root Markdown files |
| `test:placeholders` | Flags TODO/FIXME/XXX/PLACEHOLDER in the built site |
| `test:a11y` | Basic accessibility checks (alt text, lang attr, empty headings) |
| `test:performance` | Flags large HTML/CSS files and inline base64 images |
| `review:external_links` | Live external-URL check via html-proofer (slow, needs network) |
| `review:compare_deployed_sites` | Diffs staging vs production over HTTP |
| `lint` | `format:ruby` + `format:prettier` |
| `format` | `format:ruby_fix` + `format:prettier_fix` |
| `format:ruby` / `format:ruby_fix` | StandardRB check / auto-fix |
| `format:prettier` / `format:prettier_fix` | Prettier check / auto-fix |
| `outdated` / `outdated:direct` / `outdated:all` | `bundle outdated` wrappers |

### Setup

#### Option 1 — RubyGems (recommended)

```ruby
# Gemfile
gem "opennews-rake-tasks"
```

```sh
bundle install
```

#### Option 2 — git source (no publish step, useful during development)

```ruby
# Gemfile
gem "opennews-rake-tasks", github: "OpenNews/opennews-actions", glob: "opennews-rake-tasks.gemspec"
```

#### Option 3 — GitHub Packages

```ruby
# Gemfile
source "https://rubygems.pkg.github.com/OpenNews" do
  gem "opennews-rake-tasks"
end
```

> Requires a `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` token set in the environment or `~/.bundle/config`.

#### Option 4 — separate `opennews-rake-tasks` repo

Publish the gem from its own dedicated repo and reference it like Option 1.

**Distribution options comparison:**

Option | Pros | Cons
------ | ---- | ----
RubyGems public gem | Most standard; Dependabot works out of the box; easy for public and private repos | Requires publish & version management; possibly public
GitHub Packages gem | Keeps in-org; works for private repos | Requires token config in Gemfile; lock-in to GH infra
GitHub-only (gem '...', github:) | No publish step, easy to update from HEAD or tag | Ties Gemfile to repo structure; Dependabot may not fully support
Separate opennews-rake-tasks repo | Clean separation, can be public or private | One more repo to track/maintain

### Usage

Add one line to your `Rakefile`:

```ruby
require "opennews/rake_tasks"
```

All tasks are now available via `bundle exec rake`.

### Extending / overriding

Tasks that rely on repo-specific ignore lists or file requirements are configurable. Call `OpenNews::RakeTasks.configure` **before** (or after) loading the tasks — it updates the shared `Configuration` object that every task reads at runtime.

```ruby
# Rakefile
require "opennews/rake_tasks"

OpenNews::RakeTasks.configure do |config|
  # Add site-specific URLs to skip in internal link checks
  config.html_proofer_ignore_urls += [
    /mitrakalita\.com/,
    %r{opennews\.us5\.list-manage\.com/},
  ]

  # Add site-specific URLs to skip in external link review
  config.external_links_ignore_urls += [
    /etherpad\.mozilla\.org/,
    /lcc-slack\.herokuapp\.com/,
  ]

  # Skip html-proofer checks in specific directories
  config.html_proofer_ignore_files << %r{blog/}

  # Remove package.json from required-file checks if this repo has no npm setup
  config.required_files -= ["package.json"]
end
```

All configuration attributes and their defaults are documented in
[`lib/opennews/rake_tasks/configuration.rb`](lib/opennews/rake_tasks/configuration.rb).

### Upgrading

Update the gem version in `Gemfile` (or let Dependabot open a PR) and run `bundle update opennews-rake-tasks`.

### Development

```sh
git clone https://github.com/OpenNews/opennews-actions.git
cd opennews-actions
bundle install   # installs gem dependencies declared in opennews-rake-tasks.gemspec
```

To build the gem locally:

```sh
gem build opennews-rake-tasks.gemspec
```
