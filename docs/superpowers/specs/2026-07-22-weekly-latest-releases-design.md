# Weekly Latest Releases Design

## Objective

Keep the Action's default wget2, OpenSSL, and zlib sources on their latest non-prerelease GitHub Releases, rebuild the universal macOS binary every week, and refresh the public `curl` download only after the complete build and test pipeline passes.

## Chosen approach

The repository will retain audited version and SHA-256 pins in one tracked manifest, `versions.env`. A weekly updater will query each official upstream repository's `releases/latest` endpoint, select the expected source archive, require a SHA-256 digest, and update the manifest when upstream versions change. This provides automatic updates without making identical commits resolve to different source code.

Explicit Action inputs remain supported. An omitted version or checksum uses the tracked manifest value; a supplied value overrides it. This preserves reproducible callers while making the normal Action path follow the automatically maintained defaults.

## Components

### Version manifest

`versions.env` is the single source of truth for default versions and archive SHA-256 values. Build and smoke-test scripts load this file. `action.yml` leaves the version and checksum input defaults empty so the shell implementation can use the manifest without duplicating values.

### Resolver and updater

`scripts/resolve-versions.sh` queries the official GitHub Releases API for:

- `rockdaboot/wget2`
- `openssl/openssl`
- `madler/zlib`

For each release it validates the tag prefix, finds the exact expected `.tar.gz` asset, and requires the API asset digest to be a 64-character SHA-256 value. It writes a complete candidate manifest, failing closed if metadata is absent or malformed.

`scripts/update-versions.sh` invokes the resolver and atomically replaces `versions.env` only when the candidate differs. It exposes whether a change occurred for workflow use.

### Weekly workflow

`.github/workflows/weekly.yml` runs once each week and may also be started manually. It grants only `contents: write` and `actions: write`, checks out `main`, runs the updater, commits a changed manifest as `github-actions[bot]`, pushes it, and dispatches `build.yml` with release publication enabled. It dispatches the build even when no dependency changed, satisfying the weekly rebuild requirement.

### Build and release workflow

`build.yml` accepts a boolean `publish-release` workflow-dispatch input. Existing push and pull-request builds continue to compile and test without publishing.

After both native builds and universal packaging pass, a guarded release job downloads the tested universal artifact. It creates or updates release tag `v<wget2-version>`, uploads `wget2` and `SHA256SUMS` with replacement enabled, and marks the release as latest. Thus `/releases/latest/download/wget2` changes only after successful tests.

## Data flow

1. The weekly workflow resolves official latest release metadata.
2. A changed `versions.env` is committed to `main`; an unchanged manifest is left untouched.
3. The weekly workflow dispatches the standard build on current `main`.
4. Native Apple Silicon and Intel runners build and test their binaries.
5. The packaging job combines, signs, tests, and checksums the universal binary.
6. Only a dispatch explicitly requesting publication may replace public release assets.

## Failure behavior

- Missing releases, unexpected tags, missing assets, malformed digests, or API failures stop the updater without changing the manifest.
- Build failures prevent packaging and release publication.
- Packaging or checksum failures prevent release publication.
- Ordinary pushes and pull requests never modify releases.
- An existing release is updated in place; a new wget2 version creates a new latest release.

## Verification

Tests will cover manifest loading, release-metadata parsing with fixtures, failure on missing or malformed asset digests, the weekly schedule and permissions contract, publication gating, and current Action behavior. Local verification will build with the resolved current versions. Hosted verification will manually run the weekly workflow, observe its dispatched build, and confirm the public `curl` URL, checksum, architectures, signature, and HTTPS behavior.
