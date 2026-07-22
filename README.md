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
| `wget2-version` | `2.2.1` | wget2 source version |
| `wget2-sha256` | Pinned | wget2 archive digest |
| `openssl-version` | `3.5.7` | OpenSSL source version |
| `openssl-sha256` | Pinned | OpenSSL archive digest |
| `zlib-version` | `1.3.2` | zlib source version |
| `zlib-sha256` | Pinned | zlib archive digest |

When changing a version, also supply the matching SHA-256 digest. The build fails closed when any digest differs.

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

The defaults are wget2 2.2.1, OpenSSL 3.5.7, and zlib 1.3.2. Their source archives come from the upstream GitHub releases over HTTPS and are verified against the SHA-256 values committed in `action.yml`.

The Action's shell and workflow glue is MIT licensed. The produced executable contains upstream software under its own terms, notably wget2 under GPL-3.0-or-later; OpenSSL and zlib retain their upstream licenses. Distributing a generated binary requires compliance with those licenses, including the corresponding-source obligations of the GPL.
