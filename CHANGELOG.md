# Changelog

## [Unreleased]

### Added
- Initial `opennews-rake-tasks` gem with shared Rake tasks for OpenNews Jekyll static sites
- `validate_yaml`, `check`, `build`, `serve`, `clean` core tasks
- `test` namespace: `html_proofer`, `templates`, `page_config`, `placeholders`, `a11y`, `performance`
- `review` namespace: `external_links`, `compare_deployed_sites`
- `format`/`lint` tasks wrapping StandardRB and Prettier
- `outdated` tasks wrapping `bundle outdated`
- `OpenNews::RakeTasks.configure` API for repo-specific overrides (ignore lists, required files)
