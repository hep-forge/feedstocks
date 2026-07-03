#!/usr/bin/env python3
"""Refresh the feedstock status table in the top-level README.md.

For every feedstock the table shows the latest feedstock git tag next to
what is actually published on anaconda.org (per architecture), so tag !=
published immediately exposes a failed or still-running build. Run it
AFTER a rebuild wave has finished (see scripts/arch_status.sh), then
commit the README:

    python3 scripts/update_readme_status.py
    git add README.md && git commit -m "docs: refresh feedstock status table"

The table lives between the status:begin/status:end markers; everything
else in README.md is left untouched.
"""
import json
import re
import subprocess
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

ORG = "hep-forge"
ROOT = Path(__file__).resolve().parent.parent
BEGIN = "<!-- status:begin -->"
END = "<!-- status:end -->"

# anaconda.org subdir -> table column
ARCHES = {"linux-64": "amd64", "linux-aarch64": "arm64"}


def latest_tag(feedstock: Path) -> str:
    out = subprocess.run(
        ["git", "-C", str(feedstock), "tag", "--sort=-v:refname"],
        capture_output=True, text=True,
    ).stdout.split()
    if not out:
        # stale local clone: fall back to the remote's tags
        remote = subprocess.run(
            ["git", "-C", str(feedstock), "ls-remote", "--tags", "origin"],
            capture_output=True, text=True, timeout=30,
        ).stdout
        out = sorted((line.split("refs/tags/", 1)[1]
                      for line in remote.splitlines()
                      if "refs/tags/" in line and not line.endswith("^{}")),
                     reverse=True)
    # CI only fires on numeric tags; prefer those over master/beta/rNN
    numeric = [t for t in out if re.match(r"^\d", t)]
    return (numeric or out or [""])[0]


def version_key(v: str):
    """Order versions numerically where possible ('6.38.04' > '6.4.2')."""
    return [int(p) if p.isdigit() else -1 for p in re.split(r"[._-]", v)]


def published(pkg: str) -> dict:
    """{'version': str, 'linux-64': bool, 'linux-aarch64': bool} or {}."""
    url = f"https://api.anaconda.org/package/{ORG}/{pkg}"
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            data = json.load(resp)
    except Exception:
        return {}
    # 'latest_version' can lag, and pre-policy '*.dev' uploads still
    # linger on the channel: ignore dev versions unless nothing else
    # exists, and order the rest numerically ourselves.
    versions = {f.get("version", "") for f in data.get("files", [])}
    releases = {v for v in versions if "dev" not in v} or versions
    latest = max(releases, key=version_key, default=data.get("latest_version", ""))
    state = {"version": latest, **{s: False for s in ARCHES}}
    for f in data.get("files", []):
        if f.get("version") != latest:
            continue
        subdir = f.get("attrs", {}).get("subdir", "")
        for s in (ARCHES if subdir == "noarch" else [subdir]):
            if s in ARCHES:
                state[s] = True
    return state


def row(feedstock: Path) -> str:
    pkg = feedstock.name.replace("-feedstock", "")
    tag = latest_tag(feedstock) or "—"
    pub = published(pkg)
    if not pub or not pub.get("version"):
        return f"| [{pkg}](https://github.com/{ORG}/{pkg}-feedstock) | `{tag}` | — | ❌ | ❌ |"
    marks = {s: ("✅" if pub[s] else "❌") for s in ARCHES}
    ver = pub["version"]
    ver_cell = f"`{ver}`" if ver == tag else f"`{ver}` ⚠️"
    return (f"| [{pkg}](https://github.com/{ORG}/{pkg}-feedstock) | `{tag}` | "
            f"[{ver_cell}](https://anaconda.org/{ORG}/{pkg}) | "
            f"{marks['linux-64']} | {marks['linux-aarch64']} |")


def main() -> int:
    feedstocks = sorted(p for p in (ROOT / "feedstocks").glob("*-feedstock")
                        if (p / "recipe" / "meta.yaml").exists())
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(row, feedstocks))

    table = "\n".join([
        f"_Last refreshed: {date.today().isoformat()} "
        f"(`python3 scripts/update_readme_status.py`)_",
        "",
        "| Feedstock | Latest tag | Published | amd64 | arm64 |",
        "|-----------|------------|-----------|-------|-------|",
        *rows,
        "",
        "⚠️ = published version differs from the latest feedstock tag "
        "(build failed or still running).",
    ])

    readme = ROOT / "README.md"
    text = readme.read_text()
    if BEGIN not in text or END not in text:
        print(f"Markers {BEGIN} / {END} not found in README.md", file=sys.stderr)
        return 1
    text = re.sub(
        re.escape(BEGIN) + r".*?" + re.escape(END),
        BEGIN + "\n" + table + "\n" + END,
        text, flags=re.DOTALL,
    )
    readme.write_text(text)
    print(f"Updated {readme} ({len(rows)} feedstocks)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
