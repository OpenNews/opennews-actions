# opennews-actions

This repo contains two things:

1. **Shared GitHub Actions** — reusable workflows and composite actions for OpenNews Jekyll sites (test, deploy, health-check). See the `jekyll-build/`, `jekyll-deploy-s3/`, and `jekyll-health-check/` directories.
2. **`opennews-rake-tasks` Ruby gem** — shared Rake tasks for local development and CI across all OpenNews Jekyll static sites.

Docs: <https://docs.github.com/en/actions/how-tos/reuse-automations/share-with-your-organization>

---

## `opennews-rake-tasks` gem

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
