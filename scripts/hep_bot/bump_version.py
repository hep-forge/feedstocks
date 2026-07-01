#!/usr/bin/env python3
"""
Update a feedstock's meta.yaml with a new version and refreshed sha256.

Usage:
    python bump_version.py <feedstock-name> <new-version>

Example:
    python bump_version.py fastjet 3.5.2
"""
import hashlib
import re
import sys
from pathlib import Path

import requests
import yaml

REPO_ROOT = Path(__file__).parents[2]
SOURCES = yaml.safe_load((Path(__file__).parent / "sources.yaml").read_text())


def fetch_sha256(url: str) -> str:
    print(f"  Downloading {url} for sha256...")
    r = requests.get(url, timeout=120, stream=True)
    r.raise_for_status()
    h = hashlib.sha256()
    for chunk in r.iter_content(chunk_size=65536):
        h.update(chunk)
    return h.hexdigest()


def tarball_url(feedstock: str, version: str) -> str | None:
    """Reconstruct the tarball URL from the source url template(s) in meta.yaml.

    Recipes that support multiple major versions often have more than one
    `url:` line gated by a jinja conditional (e.g. hepmc's HepMC-v2 vs
    HepMC3-v3 archive naming). Rather than parse the conditional, just try
    each candidate template and use whichever one actually resolves.
    """
    meta_path = REPO_ROOT / "feedstocks" / f"{feedstock}-feedstock" / "recipe" / "meta.yaml"
    text = meta_path.read_text()
    templates = re.findall(r'url:\s*"?([^"\n]+)"?', text)
    for url_template in templates:
        url = re.sub(r'\{\{\s*version\s*\}\}', version, url_template.strip())
        try:
            r = requests.head(url, timeout=15, allow_redirects=True)
            if r.status_code == 200:
                return url
        except Exception:
            continue
    return None


def bump(feedstock: str, new_version: str) -> None:
    meta_path = REPO_ROOT / "feedstocks" / f"{feedstock}-feedstock" / "recipe" / "meta.yaml"
    if not meta_path.exists():
        raise FileNotFoundError(f"No recipe at {meta_path}")

    url = tarball_url(feedstock, new_version)
    if not url:
        raise ValueError(f"Could not determine tarball URL for {feedstock}")

    sha256 = fetch_sha256(url)

    text = meta_path.read_text()

    # Find the existing first version key and replace the whole versions dict
    # Pattern: versions = { "X.Y.Z": "sha256hex", ... }
    old_match = re.search(r'(versions\s*=\s*\{[^}]*?\})', text, re.DOTALL)
    if not old_match:
        raise ValueError(f"Could not find versions dict in {meta_path}")

    new_versions_block = f'versions = {{\n    "{new_version}": "{sha256}"\n}}'
    text = text[:old_match.start()] + new_versions_block + text[old_match.end():]

    meta_path.write_text(text)
    print(f"Updated {meta_path}: version={new_version}, sha256={sha256[:12]}...")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <feedstock> <new-version>", file=sys.stderr)
        sys.exit(1)
    bump(sys.argv[1], sys.argv[2])
