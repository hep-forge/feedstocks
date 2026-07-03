#!/usr/bin/env python3
"""Generate README.md for a feedstock from its recipe/meta.yaml.

The README is hep-forge-flavored on purpose: conda-smithy writes
conda-forge badges/channels/links, and this script replaces them with
the hep-forge equivalents, including per-architecture (linux-amd64 /
linux-arm64) publication state queried live from api.anaconda.org at
render time.
"""
import json
import sys
import re
import urllib.request
import yaml
from pathlib import Path

# anaconda.org subdir -> human-readable architecture label
ARCHES = {
    "linux-64": "linux-amd64",
    "linux-aarch64": "linux-arm64",
}


def extract_meta(meta_path: Path) -> dict:
    text = meta_path.read_text()
    # Strip Jinja2 before YAML parsing; replace expressions with placeholder
    text = re.sub(r'\{%.*?%\}', '', text, flags=re.DOTALL)
    text = re.sub(r'\{\{.*?\}\}', 'JINJA_VALUE', text)
    return yaml.safe_load(text) or {}


def arch_state(org: str, pkg: str) -> dict:
    """Latest published version per architecture, from api.anaconda.org.

    Returns {subdir: version-or-None}; None means not published. noarch
    packages count for every architecture. On network failure returns an
    empty dict so the README omits stale claims instead of guessing.
    """
    url = f"https://api.anaconda.org/package/{org}/{pkg}"
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            data = json.load(resp)
    except Exception:
        return {}
    latest = data.get("latest_version", "")
    state = {subdir: None for subdir in ARCHES}
    for f in data.get("files", []):
        subdir = f.get("attrs", {}).get("subdir", "")
        version = f.get("version", "")
        if version != latest:
            continue
        targets = list(ARCHES) if subdir == "noarch" else [subdir]
        for t in targets:
            if t in state:
                state[t] = version
    return state


def arch_table(org: str, pkg: str) -> str:
    state = arch_state(org, pkg)
    if not state:
        return (f"State per architecture: see the platforms badge above or "
                f"[anaconda.org/{org}/{pkg}](https://anaconda.org/{org}/{pkg}).\n")
    rows = []
    for subdir, label in ARCHES.items():
        version = state.get(subdir)
        cell = f"✅ `{version}`" if version else "❌ not published"
        rows.append(f"| {label} (`{subdir}`) | {cell} |")
    body = "\n".join(rows)
    return f"""\
| Architecture | Latest published |
|--------------|------------------|
{body}

_As of the last feedstock render; the badges above are live._
"""


def make_readme(feedstock_dir: Path, org: str) -> str:
    meta = extract_meta(feedstock_dir / "recipe" / "meta.yaml")
    repo = feedstock_dir.name
    pkg_name = meta.get("package", {}).get("name", repo.replace("-feedstock", ""))
    # pkg name might be "JINJA_VALUE" if fully dynamic; fall back to dir name
    if pkg_name == "JINJA_VALUE":
        pkg_name = repo.replace("-feedstock", "")
    home = meta.get("about", {}).get("home", "")
    summary = meta.get("about", {}).get("summary", "")
    maintainers = meta.get("extra", {}).get("recipe-maintainers", [])

    pkg_link = f"[{pkg_name}]({home})" if home else pkg_name
    maintainer_lines = "".join(
        f"* [@{m}](https://github.com/{m}/)\n" for m in maintainers
    )
    # shields.io static badges use "-" as a separator; literal dashes
    # must be doubled (hep-forge -> hep--forge)
    badge_text = f"{org}%2F{pkg_name}".replace("-", "--")
    prefix_badge = (
        f"[![hep-forge](https://img.shields.io/badge/package-{badge_text}-orange.svg)]"
        f"(https://anaconda.org/{org}/{pkg_name})"
    )

    return f"""\
# {repo}

{prefix_badge}
[![Build & Upload](https://github.com/{org}/{repo}/actions/workflows/autoupload.yml/badge.svg)](https://github.com/{org}/{repo}/actions/workflows/autoupload.yml)
[![Anaconda Version](https://anaconda.org/{org}/{pkg_name}/badges/version.svg)](https://anaconda.org/{org}/{pkg_name})
[![Anaconda Platforms](https://anaconda.org/{org}/{pkg_name}/badges/platforms.svg)](https://anaconda.org/{org}/{pkg_name})

Feedstock for {pkg_link} — part of [hep-forge](https://anaconda.org/{org}).
Builds linux-amd64 + linux-arm64 in one matrix workflow and uploads to the
[{org}](https://anaconda.org/{org}) Anaconda channel.

{summary}

## Architectures

{arch_table(org, pkg_name)}

## Install

```bash
conda install -c {org} -c conda-forge {pkg_name}
```

## Maintainers

{maintainer_lines}
"""


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <feedstock-dir> [org]", file=sys.stderr)
        sys.exit(1)
    feedstock = Path(sys.argv[1])
    org = sys.argv[2] if len(sys.argv) > 2 else "hep-forge"
    readme = feedstock / "README.md"
    readme.write_text(make_readme(feedstock, org))
    print(f"Updated {readme}")
