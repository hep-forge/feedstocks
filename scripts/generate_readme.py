#!/usr/bin/env python3
"""Generate README.md for a feedstock from its recipe/meta.yaml."""
import sys
import re
import yaml
from pathlib import Path


def extract_meta(meta_path: Path) -> dict:
    text = meta_path.read_text()
    # Strip Jinja2 before YAML parsing; replace expressions with placeholder
    text = re.sub(r'\{%.*?%\}', '', text, flags=re.DOTALL)
    text = re.sub(r'\{\{.*?\}\}', 'JINJA_VALUE', text)
    return yaml.safe_load(text) or {}


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

    return f"""\
# {repo}

[![Build & Upload](https://github.com/{org}/{repo}/actions/workflows/autoupload.yml/badge.svg)](https://github.com/{org}/{repo}/actions/workflows/autoupload.yml)
[![Anaconda Version](https://anaconda.org/{org}/{pkg_name}/badges/version.svg)](https://anaconda.org/{org}/{pkg_name})
[![Anaconda Platforms](https://anaconda.org/{org}/{pkg_name}/badges/platforms.svg)](https://anaconda.org/{org}/{pkg_name})

Feedstock for {pkg_link} — part of [hep-forge](https://anaconda.org/{org}).
Builds linux-amd64 + linux-arm64 in one matrix workflow and uploads to the
[{org}](https://anaconda.org/{org}) Anaconda channel.

{summary}

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
