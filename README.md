# Static wget2 for macOS

A GitHub Action that builds a portable, single-file [wget2](https://github.com/rockdaboot/wget2) executable for native Apple Silicon or Intel macOS. This repository's workflow builds both architectures, tests them on native runners, and combines them into one universal binary.

[![Build static wget2](https://github.com/seva3125/static-wget2-macos/actions/workflows/build.yml/badge.svg)](https://github.com/seva3125/static-wget2-macos/actions/workflows/build.yml)

## Use the Action

```yaml
name: Build wget2
on: workflow_dispatch

jobs:
  wget2:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: seva3125/static-wget2-macos@main
        with:
          output: dist/wget2
      - run: dist/wget2 --version
```

The Action builds the architecture of its runner. Use `macos-15` for Apple Silicon or `macos-15-intel` for Intel. See [the included workflow](.github/workflows/build.yml) for a complete universal-binary example.

Inputs:

| Input | Default | Purpose |
| --- | --- | --- |
| `output` | `dist/wget2` | Native executable destination |
| `deployment-target` | `13.0` | Minimum macOS deployment target |
| `wget2-version` | Tracked latest | wget2 source version |
| `wget2-sha256` | Tracked digest | wget2 archive digest |
| `openssl-version` | Tracked latest | OpenSSL source version |
| `openssl-sha256` | Tracked digest | OpenSSL archive digest |
| `zlib-version` | Tracked latest | zlib source version |
| `zlib-sha256` | Tracked digest | zlib archive digest |

Empty version and digest inputs use the values in [`versions.env`](versions.env). A weekly workflow updates that manifest from each official project's latest non-prerelease GitHub Release and records GitHub's SHA-256 asset digest. Explicit inputs override the manifest; when overriding a version, also supply its matching digest. Every archive is verified before extraction.

## Download the tested universal binary

Release assets are public and do not require GitHub authentication. Download and verify the latest universal binary with `curl`:

```bash
curl -fL -o wget2 https://github.com/seva3125/static-wget2-macos/releases/latest/download/wget2
curl -fL -o SHA256SUMS https://github.com/seva3125/static-wget2-macos/releases/latest/download/SHA256SUMS
chmod +x wget2
shasum -a 256 -c SHA256SUMS
./wget2 --version
```

The release binary is produced and tested by the repository's [Build static wget2 workflow](https://github.com/seva3125/static-wget2-macos/actions/workflows/build.yml). Per-run workflow artifacts remain available separately for 14 days.

## Automatic weekly updates

The [weekly updater](.github/workflows/weekly.yml) runs every Monday at 04:17 UTC. It resolves the latest stable wget2, OpenSSL, and zlib releases, commits changed version pins, and dispatches the complete native and universal build even when the pins are unchanged. The public `latest` release assets are replaced only after both architecture builds and every packaging test pass.

Release tags record all source versions, for example `wget2-2.2.1-openssl-4.0.1-zlib-1.3.2`. The stable `curl` URL remains `/releases/latest/download/wget2` across version changes.

## What “static” means on macOS

macOS does not provide a static `libSystem`, so a completely static Mach-O executable is not supported. This project links wget2, libwget, OpenSSL, and zlib into the executable. `otool -L` is tested to allow only Apple-provided libraries and frameworks under `/usr/lib` and `/System/Library`; no Homebrew or other third-party dynamic libraries are required.

Included capabilities:

- HTTP and HTTPS through OpenSSL
- redirects, recursion, and the core wget2 downloader
- gzip content decoding through zlib
- native `arm64` and `x86_64` slices in the universal artifact

Disabled to keep the build reproducible and self-contained:

- HTTP/2, IDN/IDN2, PSL, HSTS database integration, and DANE
- GPGME signature verification and runtime plugins
- Brotli, Zstandard, Lzip, Bzip2, and LZMA codecs
- PCRE and MicroHTTPD integrations
- translated messages and generated documentation

## Local build and test

On macOS with Xcode Command Line Tools, `curl`, Python 3, and standard build tools:

```bash
scripts/build.sh dist/wget2
scripts/test.sh dist/wget2
```

Set `KEEP_BUILD_DIR=1` to retain the temporary source and build trees for investigation.

## Versions and provenance

The currently tracked releases are wget2 2.2.1, OpenSSL 4.0.1, and zlib 1.3.2. Their source archives come from official upstream GitHub Releases over HTTPS and are verified against the SHA-256 values committed in `versions.env`.

The Action's shell and workflow glue is MIT licensed. The produced executable contains upstream software under its own terms, notably wget2 under GPL-3.0-or-later; OpenSSL and zlib retain their upstream licenses. Distributing a generated binary requires compliance with those licenses, including the corresponding-source obligations of the GPL.
