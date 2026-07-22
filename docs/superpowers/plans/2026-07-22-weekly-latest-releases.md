# Weekly Latest Releases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically track the latest stable wget2, OpenSSL, and zlib releases, rebuild weekly, and update the public universal-binary release only after all tests pass.

**Architecture:** A tracked `versions.env` manifest supplies reproducible defaults. Focused resolver and updater scripts maintain it from official GitHub Release metadata, a weekly workflow commits changed pins and dispatches the normal build, and a guarded release job publishes the tested universal artifact under a tag containing all three source versions.

**Tech Stack:** Bash, Python 3 standard library, GitHub Actions, GitHub CLI, GitHub Releases API, Mach-O tooling.

---

## File map

- Create `versions.env`: one source of truth for default versions and SHA-256 values.
- Create `scripts/resolve-versions.py`: parse and validate one GitHub Release document.
- Create `scripts/resolve-versions.sh`: fetch three official latest releases and emit a manifest.
- Create `scripts/update-versions.sh`: atomically update the tracked manifest.
- Create `tests/fixtures/*.json`: deterministic upstream metadata fixtures.
- Create `tests/test-resolve-versions.sh`: resolver success and failure regression tests.
- Create `.github/workflows/weekly.yml`: weekly update and build dispatch orchestration.
- Modify `action.yml`, `scripts/build.sh`, and `scripts/test.sh`: load manifest defaults while preserving overrides.
- Modify `.github/workflows/build.yml`: gated release publication.
- Modify `tests/test-action-contract.sh`: workflow, permissions, schedule, and publication contracts.
- Modify `README.md`: automatic update policy and current tracked versions.

### Task 1: Deterministic release metadata parser

**Files:**
- Create: `scripts/resolve-versions.py`
- Create: `tests/fixtures/wget2-release.json`
- Create: `tests/fixtures/openssl-release.json`
- Create: `tests/fixtures/zlib-release.json`
- Create: `tests/fixtures/malformed-release.json`
- Create: `tests/test-resolve-versions.sh`

- [ ] **Step 1: Write the failing parser tests**

Test exact version, URL, and digest extraction from fixture JSON, plus rejection of an unexpected tag, missing asset, and malformed digest:

```bash
python3 scripts/resolve-versions.py \
  tests/fixtures/wget2-release.json v \
  'wget2-{version}.tar.gz'

if python3 scripts/resolve-versions.py \
  tests/fixtures/malformed-release.json v \
  'wget2-{version}.tar.gz'; then
  echo 'FAIL: malformed digest accepted' >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test and verify RED**

Run: `tests/test-resolve-versions.sh`

Expected: failure because `scripts/resolve-versions.py` does not exist.

- [ ] **Step 3: Implement the minimal parser**

The parser accepts `JSON_PATH TAG_PREFIX ASSET_TEMPLATE`, requires a published non-prerelease release, strips the exact tag prefix, renders the asset name, and prints three tab-separated fields:

```python
print(f"{version}\t{asset['browser_download_url']}\t{digest.removeprefix('sha256:')}")
```

It exits nonzero unless the digest matches `[0-9a-f]{64}`.

- [ ] **Step 4: Run the test and verify GREEN**

Run: `tests/test-resolve-versions.sh`

Expected: `PASS: release metadata resolver tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/resolve-versions.py tests/fixtures tests/test-resolve-versions.sh
git commit -m "feat: validate upstream release metadata"
```

### Task 2: Tracked manifest and automatic updater

**Files:**
- Create: `versions.env`
- Create: `scripts/resolve-versions.sh`
- Create: `scripts/update-versions.sh`
- Modify: `tests/test-resolve-versions.sh`

- [ ] **Step 1: Extend the failing tests**

Inject a fixture directory through `RELEASE_FIXTURE_DIR`, verify the emitted manifest contains all six expected assignments, verify `update-versions.sh` reports `changed=false` for identical content, and verify it reports `changed=true` for a stale copy without touching the repository manifest.

- [ ] **Step 2: Run the test and verify RED**

Run: `tests/test-resolve-versions.sh`

Expected: failure because the shell resolver and updater are missing.

- [ ] **Step 3: Implement manifest resolution**

`scripts/resolve-versions.sh` fetches official `releases/latest` JSON using authenticated `curl` when `GITHUB_TOKEN` is present, delegates parsing to `resolve-versions.py`, and emits:

```dotenv
WGET2_VERSION_DEFAULT=2.2.1
WGET2_SHA256_DEFAULT=d7544b13e37f18e601244fce5f5f40688ac1d6ab9541e0fbb01a32ee1fb447b4
OPENSSL_VERSION_DEFAULT=4.0.1
OPENSSL_SHA256_DEFAULT=2db3f3a0d6ea4b59e1f094ace2c8cd536dffb87cdc39084c5afa1e6f7f37dd09
ZLIB_VERSION_DEFAULT=1.3.2
ZLIB_SHA256_DEFAULT=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
```

`scripts/update-versions.sh [manifest]` writes a candidate beside the target, compares it, replaces it only on change, and appends `changed=true|false` to `$GITHUB_OUTPUT` when defined.

- [ ] **Step 4: Run resolver tests and verify GREEN**

Run: `tests/test-resolve-versions.sh`

Expected: all parser and updater cases pass.

- [ ] **Step 5: Resolve live upstream metadata**

Run: `scripts/resolve-versions.sh > /tmp/static-wget2-versions.env && diff -u versions.env /tmp/static-wget2-versions.env`

Expected: no difference after the manifest is updated to the official latest stable releases.

- [ ] **Step 6: Commit**

```bash
git add versions.env scripts/resolve-versions.sh scripts/update-versions.sh tests/test-resolve-versions.sh
git commit -m "feat: resolve latest dependency releases"
```

### Task 3: Manifest-backed Action defaults

**Files:**
- Modify: `action.yml`
- Modify: `scripts/build.sh`
- Modify: `scripts/test.sh`
- Modify: `tests/test-action-contract.sh`

- [ ] **Step 1: Write the failing contract tests**

Require `action.yml` version and digest defaults to be empty, require `build.sh` and `test.sh` to source `versions.env`, and require all explicit inputs to remain wired into environment variables.

- [ ] **Step 2: Run the test and verify RED**

Run: `tests/test-action-contract.sh`

Expected: failure because current defaults are duplicated literals.

- [ ] **Step 3: Implement manifest-backed defaults**

Source `versions.env` from the repository root and select each value with explicit input precedence:

```bash
wget2_version="${WGET2_VERSION:-$WGET2_VERSION_DEFAULT}"
wget2_sha256="${WGET2_SHA256:-$WGET2_SHA256_DEFAULT}"
```

Apply the same pattern to OpenSSL and zlib. Change Action input descriptions to state that empty means tracked latest, with `default: ""`.

- [ ] **Step 4: Verify GREEN and explicit overrides**

Run: `tests/test-action-contract.sh && tests/test-lib.sh && bash -n scripts/*.sh tests/*.sh`

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add action.yml scripts/build.sh scripts/test.sh tests/test-action-contract.sh
git commit -m "feat: use tracked latest versions by default"
```

### Task 4: Weekly orchestration

**Files:**
- Create: `.github/workflows/weekly.yml`
- Modify: `tests/test-action-contract.sh`

- [ ] **Step 1: Write the failing workflow contract**

Require a weekly cron, manual dispatch, `contents: write`, `actions: write`, updater execution, explicit manifest-only staging, bot identity, push, and `gh workflow run build.yml --ref main -f publish-release=true`.

- [ ] **Step 2: Run the contract test and verify RED**

Run: `tests/test-action-contract.sh`

Expected: failure because `.github/workflows/weekly.yml` is absent.

- [ ] **Step 3: Implement the weekly workflow**

Use a non-round cron such as `17 4 * * 1`, set a 15-minute timeout, authenticate `gh` using `${{ github.token }}`, commit only `versions.env` when changed, push to `main`, and always dispatch the build.

- [ ] **Step 4: Run contract and YAML validation**

Run: `tests/test-action-contract.sh` and parse both workflows with Ruby's YAML parser.

Expected: PASS and valid YAML.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/weekly.yml tests/test-action-contract.sh
git commit -m "ci: update and rebuild dependencies weekly"
```

### Task 5: Guarded release refresh

**Files:**
- Modify: `.github/workflows/build.yml`
- Modify: `tests/test-action-contract.sh`

- [ ] **Step 1: Write failing publication-gate tests**

Require a boolean `publish-release` dispatch input defaulting false, a release job needing `package`, an exact event/input guard, `contents: write` only on that job, universal artifact download, a release tag containing all three manifest versions, and `gh release upload --clobber` or `gh release create --latest`.

- [ ] **Step 2: Run the test and verify RED**

Run: `tests/test-action-contract.sh`

Expected: failure because release publication is not implemented.

- [ ] **Step 3: Implement publication after package success**

The job sources `versions.env`, builds this tag:

```bash
release_tag="wget2-$WGET2_VERSION_DEFAULT-openssl-$OPENSSL_VERSION_DEFAULT-zlib-$ZLIB_VERSION_DEFAULT"
```

It updates an existing tuple release with `gh release upload --clobber` and `gh release edit --latest`; otherwise it creates a latest release with the three versions in its notes.

- [ ] **Step 4: Run workflow contract and lint checks**

Run: `tests/test-action-contract.sh`, `actionlint`, and ShellCheck at warning severity.

Expected: all pass with no warnings.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build.yml tests/test-action-contract.sh
git commit -m "ci: refresh tested release assets"
```

### Task 6: Documentation, build, audit, and hosted verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document automatic updates**

Explain that empty inputs use weekly maintained pins, explicit inputs override them, the updater follows latest non-prerelease releases, the weekly run republishes only after tests, and the stable `curl` URL is unchanged.

- [ ] **Step 2: Run the full local suite**

Run:

```bash
tests/test-resolve-versions.sh
tests/test-lib.sh
tests/test-action-contract.sh
bash -n scripts/*.sh tests/*.sh
scripts/build.sh dist/wget2
scripts/test.sh dist/wget2
```

Expected: all tests pass and the binary reports the manifest wget2 version.

- [ ] **Step 3: Conduct the required code audit**

Review the complete diff, run `git diff --check`, ShellCheck, actionlint, confirm external Actions remain SHA-pinned, and verify the weekly token has no permissions beyond contents/actions writes.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md
git commit -m "docs: explain weekly latest builds"
```

- [ ] **Step 5: Publish with GitHub CLI**

Run: `git push origin main` and use `gh workflow run weekly.yml --ref main`.

- [ ] **Step 6: Verify the orchestration end to end**

Watch the weekly run with `gh run watch`, identify its dispatched build, watch all three build jobs pass, and inspect the resulting release with `gh release view`.

- [ ] **Step 7: Verify the public stable URL**

Use unauthenticated `curl` to download `wget2` and `SHA256SUMS` from `/releases/latest/download/`, then verify checksum, signature, `arm64` and `x86_64` slices, system-only linkage, version, and a live HTTPS download.
