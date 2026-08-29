# Validation Contract

This repository validates the composite action with shell syntax checks, action metadata parsing, lifecycle-resolution scenarios, and config-merge smoke tests.

## Local Checks

Run these before opening or updating a PR:

```bash
make test
rabbit.ci
```

## CI

The `ci` workflow runs on pull requests and pushes to `production`. It installs
a pinned `yq` binary, runs `make test`, and uses `actionlint` for GitHub Actions
workflow linting. On pull requests, validation also requires a semantic
`package.json` version increase when `action.yml` or `bin/` changes.
