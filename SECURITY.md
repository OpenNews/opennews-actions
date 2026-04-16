# Security Policy

## Scope

This repository contains shared GitHub Actions workflows and composite actions used across multiple OpenNews production websites. Security vulnerabilities here can affect all consuming repositories.

**In scope:**
- Vulnerabilities in workflow logic or action definitions
- Insecure permissions or credential handling
- Dependency vulnerabilities in consumed actions
- Supply chain security issues

**Out of scope:**
- Vulnerabilities in consuming repositories (report to those repos directly)
- General GitHub Actions platform issues (report to GitHub)

---

## Contribution & Release Policy

### Changes affect live sites

Every merge to `main` automatically creates a new patch release and updates the floating `@v1` tag. Sites referencing `@v1` receive the update immediately with no manual intervention.

### Requirements before merging

- **All changes must go through a pull request** — direct pushes to `main` are blocked
- **PR review required** — especially for Dependabot updates; check release notes for breaking changes
- **Test against a consuming repo** before merging:
  ```yaml
  # Temporarily point at your branch
  uses: OpenNews/opennews-actions/jekyll-build@your-branch-name
  ```
  Run manually from Actions tab, confirm it works, then revert
- **Breaking changes require a new major version** (e.g., `v2`) — coordinate with team before releasing

### Automatic releases

- Merging to `main` → auto-publishes patch release (e.g., `v1.0.2` → `v1.0.3`)
- Release notes generated from PR titles
- Floating `v1` tag force-updated to latest patch
- For major versions, manually create and push the tag

## Supported Versions

We support only the latest release. Breaking changes require a new major version (e.g., `v2`). Security fixes are always released as patch updates and automatically deployed via the floating major version tag (`v1` → `v1.0.x`).

| Version | Supported          |
| ------- | ------------------ |
| v1.x    | :white_check_mark: |
| < v1.0  | :x:                |

## Reporting a Vulnerability

**Do not open public issues for security vulnerabilities.**

### Preferred: GitHub Private Vulnerability Reporting

1. Go to the [Security Advisories page](https://github.com/OpenNews/opennews-actions/security/advisories)
2. Click "Report a vulnerability"
3. Fill out the advisory form with details

### Alternative: Email

Send details to **info@opennews.org** with:
- Description of the vulnerability
- Steps to reproduce or proof of concept
- Potential impact (which consuming repos are affected)
- Suggested fix (optional)

### What to expect

- **Initial response:** Within 7 business days
- **Status update:** Within 2 week with triage decision
- **Fix timeline:** Critical issues patched within 14 days; others within 30 days
- **Disclosure:** We'll coordinate public disclosure with you after the fix is released

### After reporting

- We'll acknowledge your report and assess severity
- We may ask for additional information
- We'll develop and test a fix
- We'll release a patch and update the security advisory
- We'll credit you in the advisory (unless you prefer to remain anonymous)

## Security Best Practices for Contributors

When contributing to this repository:

- Pin third-party actions to full commit SHAs, not tags
- Use minimal required permissions in workflows
- Never log or expose secrets
- Use `actions/checkout@v6` or later (includes security fixes)
- Enable Dependabot security updates
- Review dependency updates for breaking changes before merging

## Responsible Disclosure

We follow coordinated disclosure principles. We ask that security researchers:

- Allow reasonable time for patching before public disclosure
- Avoid exploiting vulnerabilities beyond proof of concept
- Do not access or modify user data in consuming repositories
- Act in good faith to help improve security

Thank you for helping keep OpenNews projects secure.
