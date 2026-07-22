# Static wget2 for macOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish and prove a reusable GitHub Action that builds a universal, third-party-static wget2 executable for macOS.

**Architecture:** A composite Action delegates to a strict build script that compiles pinned OpenSSL, zlib, and wget2 sources in an isolated directory. Small shell helpers enforce archive checksums, Mach-O architecture, and Apple-only dynamic linkage; a native matrix builds the slices and a packaging job combines them with `lipo`.

**Tech Stack:** POSIX shell/Bash, Autoconf/Make, OpenSSL 3.5.7, zlib 1.3.2, wget2 2.2.1, GitHub Actions, Mach-O tools (`otool`, `lipo`).

---

### Task 1: Establish the test-first shell contract

**Files:**
- Create: `.gitignore`
- Create: `tests/test-lib.sh`
- Create: `tests/test-action-contract.sh`
- Create: `scripts/lib.sh`

- [ ] **Step 1: Create a feature worktree and write failing helper tests**

`tests/test-lib.sh` will create a fixture, verify its correct checksum, require an incorrect checksum to fail, call `assert_architecture` against `/usr/bin/true`, and call `assert_system_linkage` against `/usr/bin/true`. It will fail initially because `scripts/lib.sh` does not exist.

- [ ] **Step 2: Run the helper test and verify RED**

Run: `bash tests/test-lib.sh`

Expected: non-zero with `scripts/lib.sh: No such file or directory`.

- [ ] **Step 3: Implement only the tested helpers**

Create strict functions with these interfaces:

```bash
verify_sha256 EXPECTED FILE
assert_architecture BINARY EXPECTED_ARCH
assert_system_linkage BINARY
```

`assert_system_linkage` must reject every `otool -L` entry that does not begin with `/usr/lib/` or `/System/Library/`.

- [ ] **Step 4: Run the helper test and verify GREEN**

Run: `bash tests/test-lib.sh`

Expected: `PASS: shell helper tests`.

- [ ] **Step 5: Write and run the failing Action contract test**

The contract test requires `action.yml`, `scripts/build.sh`, `scripts/test.sh`, and `.github/workflows/build.yml`; it checks that the Action is composite and that the workflow names both `macos-15` and `macos-15-intel`. It must fail before those files exist.

Run: `bash tests/test-action-contract.sh`

Expected: non-zero naming the first missing file.

- [ ] **Step 6: Commit the tested helper seam**

```bash
git add .gitignore tests/test-lib.sh tests/test-action-contract.sh scripts/lib.sh
git commit -m "test: define static build contracts"
```

### Task 2: Implement the source build and composite Action

**Files:**
- Create: `scripts/build.sh`
- Create: `scripts/test.sh`
- Create: `action.yml`

- [ ] **Step 1: Implement the build script**

Use pinned defaults and verified archives:

```text
wget2 2.2.1  d7544b13e37f18e601244fce5f5f40688ac1d6ab9541e0fbb01a32ee1fb447b4
OpenSSL 3.5.7  a8c0d28a529ca480f9f36cf5792e2cd21984552a3c8e4aa11a24aa31aeac98e8
zlib 1.3.2  bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
```

The script must select `darwin64-arm64-cc` or `darwin64-x86_64-cc`, build OpenSSL with `no-shared no-module no-tests`, build zlib as a static archive, and configure wget2 with `--enable-static --disable-shared --disable-doc --disable-nls --with-ssl=openssl`. It must explicitly disable every optional integration listed in the design. It must validate the output through both helper assertions.

- [ ] **Step 2: Implement the artifact smoke test**

The test script must require a binary argument, validate native architecture and system-only linkage, assert that `wget2 --version` reports OpenSSL and zlib, serve a fixture from `python3 -m http.server` on an ephemeral port, download it, and compare SHA-256 hashes.

- [ ] **Step 3: Add the composite Action contract**

The Action exposes version, checksum, deployment-target, and output inputs. Its only step runs:

```yaml
shell: bash
run: >-
  "${{ github.action_path }}/scripts/build.sh"
  "${{ inputs.output }}"
```

with the inputs mapped into `WGET2_*`, `OPENSSL_*`, `ZLIB_*`, and `MACOSX_DEPLOYMENT_TARGET` environment variables.

- [ ] **Step 4: Run shell syntax and the partial contract test**

Run: `bash -n scripts/*.sh tests/*.sh`

Expected: zero syntax errors. `bash tests/test-action-contract.sh` must now advance to `FAIL: missing .github/workflows/build.yml`, proving that the composite Action portion of the contract has been satisfied before the workflow is added in Task 3.

- [ ] **Step 5: Commit the Action implementation**

```bash
git add action.yml scripts/build.sh scripts/test.sh
git commit -m "feat: build static wget2 on macOS"
```

### Task 3: Add native CI, universal packaging, and documentation

**Files:**
- Create: `.github/workflows/build.yml`
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Implement the native build matrix**

The build job checks out the repository, invokes `./`, runs `scripts/test.sh`, and uploads `wget2-arm64` or `wget2-x86_64`. The matrix is:

```yaml
include:
  - runner: macos-15
    arch: arm64
  - runner: macos-15-intel
    arch: x86_64
```

- [ ] **Step 2: Implement universal packaging**

A dependent `package` job downloads both artifacts, creates `dist/wget2` with `lipo -create`, asserts both architectures, checks linkage, executes the native slice, writes `dist/SHA256SUMS`, and uploads `wget2-macos-universal`.

- [ ] **Step 3: Document usage and limitations**

The README must show workflow and local composite-Action examples, list the included and excluded capabilities, explain Apple-only dynamic dependencies, identify the deployment target, and link to successful runs and artifacts generically through the repository’s Actions page.

- [ ] **Step 4: Add an MIT license for repository-authored glue code**

State clearly in the README that generated wget2 artifacts remain GPL-3.0-or-later and OpenSSL/zlib retain their upstream licenses.

- [ ] **Step 5: Run all local tests and commit**

Run: `bash tests/test-lib.sh && bash tests/test-action-contract.sh && bash -n scripts/*.sh tests/*.sh`

Expected: both tests PASS and syntax check exits zero.

```bash
git add .github/workflows/build.yml README.md LICENSE
git commit -m "ci: build and package universal macOS binary"
```

### Task 4: Build locally and audit the implementation

**Files:**
- Modify when required by an observed failure: `scripts/build.sh`, `scripts/test.sh`, `tests/*.sh`, `.github/workflows/build.yml`, `README.md`

- [ ] **Step 1: Execute the Action’s build script on the local Apple Silicon Mac**

Run: `scripts/build.sh dist/wget2`

Expected: the compiled executable is arm64, has no non-Apple dynamic dependencies, and the command exits zero.

- [ ] **Step 2: Run the real artifact smoke test**

Run: `scripts/test.sh dist/wget2`

Expected: version and local HTTP download checks pass.

- [ ] **Step 3: Run the full static suite**

Run: `bash tests/test-lib.sh && bash tests/test-action-contract.sh && bash -n scripts/*.sh tests/*.sh && git diff --check`

Expected: all commands exit zero.

- [ ] **Step 4: Audit the complete diff**

Inspect every tracked file for unsafe interpolation, unquoted paths, mutable downloads, license ambiguity, incorrect Action expressions, missing feature disclosures, and accidental files. Fix only concrete findings and rerun the applicable checks.

- [ ] **Step 5: Commit verified fixes if any**

```bash
git add scripts tests action.yml .github README.md LICENSE
git commit -m "fix: harden static build workflow"
```

### Task 5: Publish and validate GitHub Actions

**Files:**
- Modify when required by a CI failure: the smallest relevant implementation or test file

- [ ] **Step 1: Create the public repository and push main**

Run: `gh repo create seva3125/static-wget2-macos --public --source=. --remote=origin --push`

Expected: repository URL `https://github.com/seva3125/static-wget2-macos` and a pushed `main` branch.

- [ ] **Step 2: Observe the triggered workflow to completion**

Run: `gh run watch --exit-status`

Expected: both native build jobs and universal package job succeed.

- [ ] **Step 3: Download and inspect the published artifacts**

Run `gh run download` into a new temporary directory, then check the universal binary with `lipo -archs`, `otool -L`, and `--version` on the local Mac.

Expected: `arm64 x86_64`, no non-Apple libraries, and wget2 2.2.1 executes.

- [ ] **Step 4: Diagnose failures test-first and rerun**

For any CI defect, capture its log, add or strengthen the smallest regression check when feasible, verify the regression check fails before the fix, implement the fix, rerun all checks, audit the new diff, commit, and push. Repeat until a fresh workflow run and artifact inspection both pass.

- [ ] **Step 5: Perform the published-state audit**

Verify repository visibility, default branch, clean local status, commit history, successful run URL, artifact names, and README rendering. Record exact evidence for the final report.
