# Releasing Rabbit Automation Action

The action is released from `production`. Patch releases are immutable
`v1.x.y` tags; `v1` is the movable compatibility tag that callers use.

## Prepare a release

1. Bump `package.json` to the next semantic version and add matching concise
   user-facing notes at the top of `CHANGELOG.md` in the pull request that
   changes action behavior.
2. Merge the focused, reviewed pull request into `production`.
3. Test the exact `production` commit from a caller's non-production
   environment. Use `@production` only for that canary.

The `Publish release` workflow runs after every `production` push. It does
nothing unless that push changes `package.json`; then it runs `make test`,
refuses to reuse an existing tag, and publishes that GitHub release from the
merged commit. The `Verify release` workflow then validates the published tag.
After the GitHub release is created, `#rabbit-support` receives the Marketplace
handoff through `SLACK_WEBHOOK_RABBIT_SUPPORT`; the message directs the
operator to wait for verification before publishing to Marketplace.

`package.json` is the single release-version source. Its semantic version maps
to the Git tag by adding `v` and must match the first semantic heading in
`CHANGELOG.md`; `make test` enforces that contract before a release can be
published.

## Publish to GitHub Marketplace

1. Confirm the `Verify release` workflow passed for the automatically
   published semantic GitHub release, for example `v1.0.3`.
2. Open that release and, in the release form, select **Publish this Action to
   the GitHub Marketplace**. GitHub requires this UI step and may require 2FA;
   a release created only through the REST or CLI release API is not enough.
3. Keep `Deployment` as the primary Marketplace category and `Security` as the
   secondary category unless the action's public purpose changes.
4. Verify the Marketplace listing shows the new version, current `action.yml`
   metadata, and current README before changing any caller references.

The published-tag verification does not replace the pre-release caller canary
or the Marketplace UI verification.

## Promote callers

1. Move the `v1` tag to the tested immutable release commit.
2. Confirm `v1` and the patch tag resolve to the same commit with
   `git ls-remote --tags origin 'v1*'`.
3. Update reusable workflows and callers from `@production` to `@v1`.
4. Run a non-production caller plan using `@v1` before merging the consumer
   change.

Use a new major tag for breaking input, output, safety, or lifecycle-contract
changes. Keep `v1` on the latest compatible patch release; do not rewrite a
patch release tag.
