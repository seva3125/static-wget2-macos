# Static wget2 for macOS — Design

## Objective

Publish a public GitHub repository that provides a reusable GitHub Action and a reference workflow for producing a self-contained wget2 executable for both Apple Silicon and Intel macOS. The repository must build and test its own artifacts on GitHub-hosted macOS runners.

## Meaning of “static” on macOS

Apple does not provide a static `libSystem`, so a completely static Mach-O command-line program is not supported. In this project, “static” means that wget2, libwget, OpenSSL, and zlib are linked into the executable. The only permitted dynamic load commands are Apple-provided libraries and frameworks under `/usr/lib` or `/System/Library`.

## Considered approaches

1. **Homebrew binary and libraries.** This is short and full-featured, but leaves non-system Homebrew `.dylib` dependencies and therefore does not create a portable single file.
2. **Full-featured static source build.** This preserves every optional wget2 integration but requires a large, fragile dependency graph and increases build time substantially.
3. **Minimal static source build (selected).** Build pinned wget2, OpenSSL, and zlib source archives; disable optional integrations; statically link all three. This preserves the core HTTP/HTTPS downloader, recursion, redirects, and gzip support while producing a reproducible single executable.

## Repository interface

- `action.yml` is a composite Action. Inputs select the wget2, OpenSSL, and zlib versions, the minimum macOS target, and the output path.
- `scripts/build.sh` downloads verified source archives, builds static dependencies in an isolated prefix, builds wget2, rejects unexpected dynamic libraries, and copies the executable to the requested path.
- `scripts/test.sh` validates the architecture and linkage, starts a local HTTP server, downloads a fixture with the new executable, compares its checksum, and verifies HTTPS capability through the version report.
- `.github/workflows/build.yml` runs the Action on native Apple Silicon and Intel standard GitHub-hosted runners. It uploads per-architecture artifacts, joins them with `lipo` into one universal binary, smoke-tests the native slice, emits SHA-256 checksums, and uploads the universal package.

## Reproducibility and security

Every source version is pinned by default. Downloads use HTTPS and are checked against committed SHA-256 values before extraction. Shell scripts use strict error handling, quote paths, isolate temporary work, and avoid modifying the runner outside their temporary build tree and requested output.

## Feature scope

The binary includes HTTPS through OpenSSL and gzip through zlib. Optional wget2 integrations are explicitly disabled: GnuTLS, HTTP/2, IDN/IDN2, PSL, HSTS database support, DANE, GPGME, Brotli, Zstandard, Lzip, PCRE, MicroHTTPD, NLS, and runtime plugins. These exclusions are a deliberate portability trade-off and will be stated in the README.

## Tests and acceptance criteria

The work is accepted when:

1. Shell and workflow files pass syntax and static checks.
2. The build succeeds on both `macos-15` (Apple Silicon) and `macos-15-intel`.
3. Each native executable runs `wget2 --version` and downloads a local fixture correctly.
4. `otool -L` reports no non-Apple dynamic dependencies.
5. The universal executable contains `arm64` and `x86_64` slices.
6. A public GitHub repository contains the committed implementation and a successful workflow run with downloadable artifacts.

## Failure handling

Downloads, checksums, compilation, linkage validation, architecture validation, and smoke tests fail closed with explanatory output. Matrix jobs remain independent so architecture-specific failures are visible. The universal packaging job only runs after both native builds pass.
