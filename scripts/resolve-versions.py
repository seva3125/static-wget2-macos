#!/usr/bin/env python3
"""Extract a versioned source asset from GitHub Release metadata."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> "NoReturn":
    raise SystemExit(message)


if len(sys.argv) != 4:
    fail(
        "usage: resolve-versions.py RELEASE_JSON TAG_PREFIX "
        "ASSET_NAME_TEMPLATE"
    )

release_path = Path(sys.argv[1])
tag_prefix = sys.argv[2]
asset_template = sys.argv[3]

try:
    release = json.loads(release_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    fail(f"could not read release metadata: {error}")

if not isinstance(release, dict):
    fail("release metadata must be a JSON object")
if release.get("draft") or release.get("prerelease"):
    fail("release must be published and non-prerelease")

tag = release.get("tag_name")
if not isinstance(tag, str) or not tag.startswith(tag_prefix):
    fail(f"release tag does not start with {tag_prefix!r}")

version = tag[len(tag_prefix) :]
if not re.fullmatch(r"[0-9][0-9A-Za-z._-]*", version):
    fail(f"release version is invalid: {version!r}")

asset_name = asset_template.replace("{version}", version)
assets = release.get("assets")
if not isinstance(assets, list):
    fail("release assets must be a JSON array")

matches = [asset for asset in assets if asset.get("name") == asset_name]
if len(matches) != 1:
    fail(f"expected exactly one release asset named {asset_name!r}")

asset = matches[0]
url = asset.get("browser_download_url")
if not isinstance(url, str) or not url.startswith("https://github.com/"):
    fail("release asset URL must use HTTPS on github.com")

digest = asset.get("digest")
if not isinstance(digest, str):
    fail("release asset is missing its SHA-256 digest")
digest_match = re.fullmatch(r"sha256:([0-9a-f]{64})", digest)
if digest_match is None:
    fail("release asset digest is not a valid SHA-256 value")

print(f"{version}\t{url}\t{digest_match.group(1)}")
