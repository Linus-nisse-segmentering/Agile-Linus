# Software Quality Guide

This project uses an automated quality gate covering tests, linting, and local pre-commit checks.

## Quality Goals

- Keep API behavior stable through repeatable tests.
- Keep code style and maintainability consistent with RuboCop.
- Catch obvious issues before commit with shared Git hooks.
- Verify quality in CI for every pull request and every push to `main`.

## Test Framework

- Framework: RSpec
- HTTP/API testing: Rack::Test
- Coverage tool: SimpleCov

Run locally:

```bash
bundle exec rspec
```

## Linting

- Linter: RuboCop
- Config entry point: `.rubocop.yml`
- Extended rules: `backend/openapi/.rubocop.yml`

Run locally:

```bash
bundle exec rubocop
```

## CI Quality Pipeline

Workflow: `.github/workflows/quality.yml`

Pipeline steps:

1. Install dependencies with bundler cache.
2. Run RuboCop linting.
3. Run the RSpec test suite.

A pull request is expected to pass this pipeline before merge.

## Shared Git Hooks

Shared hook directory: `.githooks/`

Current hook:

- `pre-commit`: runs RuboCop and RSpec before each commit.

Enable once per local clone:

```powershell
./scripts/setup-git-hooks.ps1
```

## Quality Badges

README includes badges for:

- CI quality pipeline status
- Deployment pipeline status
- RuboCop linting
- RSpec testing

## Recommended Team Workflow

1. Run `bundle exec rubocop`.
2. Run `bundle exec rspec`.
3. Commit only when local checks pass.
4. Open a pull request and wait for CI quality checks.
