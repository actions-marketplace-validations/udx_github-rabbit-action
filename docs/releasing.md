# Releasing Rabbit Automation Action

The action is released from `production`. Patch releases are immutable
`v1.x.y` tags; `v1` is the movable compatibility tag that callers use.

## Prepare a release

1. In the pull request targeting `production`, bump `package.json` to the next
   semantic version and add matching concise user-facing notes at the top of
   `CHANGELOG.md` for the action behavior changes in that release.
2. Merge the focused, reviewed pull request into `production`.

CI rejects a production-targeting pull request that changes `action.yml` or
`bin/` unless its `package.json` version increases. `make test` also requires
the first semantic heading in `CHANGELOG.md` to match that version.

The `Publish release` workflow runs after every `production` push. It does
nothing unless that push changes the `package.json` version; then it runs
`make test`, refuses to reuse an existing tag, and publishes that GitHub
release from the merged commit. It explicitly dispatches `Verify release` for
the published tag, because release events created with `GITHUB_TOKEN` do not
start other workflows.
After the GitHub release is created, `#rabbit-support` receives a handoff
through `SLACK_WEBHOOK_RABBIT_SUPPORT` to wait for verification and check the
Marketplace listing.

`package.json` is the single release-version source. Its semantic version maps
to the Git tag by adding `v` and must match the first semantic heading in
`CHANGELOG.md`; `make test` enforces that contract before a release can be
published. A production push creates a release only when this version changes,
and its version must increase.

## GitHub Marketplace

Publishing an action to GitHub Marketplace is a one-time UI setup. This action
already has a Marketplace listing, so a published versioned release updates the
existing listing without another manual publishing step.

For the first Marketplace release only, open the release form and select
**Publish this Action to the GitHub Marketplace**. GitHub may require 2FA.
Use `Deployment` as the primary category and `Security` as the secondary
category unless the action's public purpose changes.

For every release:

1. Confirm `Verify release` passed for the published semantic tag, for example
   `v1.0.4`.
2. Confirm the Marketplace listing shows that version, the current `action.yml`
   metadata, and the current README.

Published-tag verification does not replace the caller canary or the
Marketplace listing check.

## Promote callers

1. After the semantic release is published, in a caller repository's
   non-production environment run a plan using its immutable tag, for example
   `udx/github-rabbit-action@v1.0.5`. This caller canary proves the exact
   release commit works in a real consumer workflow; it must not apply
   infrastructure.
2. Move the `v1` tag to the tested immutable release commit.
3. Compare the `v1` and new patch-tag SHAs to confirm they resolve to the same
   commit: `git ls-remote --tags origin refs/tags/v1 refs/tags/v1.0.5`.
4. Update reusable workflows and callers from `@production` to `@v1`.
5. Run a non-production caller plan using `@v1` before merging the consumer
   change.

Use a new major tag for breaking input, output, safety, or lifecycle-contract
changes. Keep `v1` on the latest compatible patch release; do not rewrite a
patch release tag.
