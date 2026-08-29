# Changelog

All notable changes to this action are recorded here. Versions follow semantic
versioning; callers should normally use the maintained `v1` major tag.

## v1.0.6 - 2026-08-29

- Default `shared_project` to `project_id` so Kubernetes modules look up the
  kubeconfig secret in the caller's own project unless told otherwise.
- Document the `k8s-config-<cluster>-<namespace>` kubeconfig secret contract.

## v1.0.5 - 2026-08-29

- Mount a temporary private copy of Google Workload Identity credentials so the
  non-root R2A container can read them without changing the caller file's mode.

## v1.0.4 - 2026-08-24

- Clarified the one-time GitHub Marketplace setup and the checks required for
  each subsequent action release. No action runtime behavior changed.

## v1.0.3 - 2026-08-18

- Added release verification, workflow linting, and a production release
  workflow that validates and publishes each new semantic version.
- Enforced ShellCheck error checks and corrected lifecycle-root discovery.

## v1.0.2 - 2026-08-18

- Made lifecycle resolution and Rabbit configuration merging self-contained.
- Added caller-selectable lifecycle policy and configuration-root inputs.
- Kept cloud identity in the caller workflow; the action consumes prepared
  runtime credentials only.

## v1.0.1 - 2026-04-30

- Initial GitHub Marketplace release.
