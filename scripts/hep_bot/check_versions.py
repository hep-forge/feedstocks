#!/usr/bin/env python3
"""
Check each feedstock's current version against the latest upstream release.
Creates a GitHub PR for each package that is behind.

Usage:
    python check_versions.py [--dry-run]

Requires: requests, pyyaml, GITHUB_TOKEN env var (for PR creation)
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import requests
import yaml

REPO_ROOT = Path(__file__).parents[2]
SOURCES = yaml.safe_load((Path(__file__).parent / "sources.yaml").read_text())
DAG = yaml.safe_load((Path(__file__).parent / "dag.yaml").read_text())


def current_version(feedstock: str) -> str | None:
    """Read the first key in the versions dict from meta.yaml."""
    meta_path = REPO_ROOT / "feedstocks" / f"{feedstock}-feedstock" / "recipe" / "meta.yaml"
    if not meta_path.exists():
        return None
    text = meta_path.read_text()
    # Extract first key from versions dict pattern: {"X.Y.Z": "sha256..."}
    m = re.search(r'versions\s*=\s*\{[^}]*?"(\d[\d.]+)"', text)
    return m.group(1) if m else None


def latest_version_html(url: str, pattern: str) -> str | None:
    """Scrape a download page for the latest version matching pattern."""
    try:
        r = requests.get(url, timeout=15)
        r.raise_for_status()
    except Exception as e:
        print(f"  WARNING: could not fetch {url}: {e}", file=sys.stderr)
        return None
    versions = re.findall(pattern, r.text)
    if not versions:
        return None
    # Sort and return highest semantic version
    from packaging.version import Version, InvalidVersion
    valid = []
    for v in versions:
        try:
            valid.append(Version(v))
        except InvalidVersion:
            pass
    return str(max(valid)) if valid else versions[-1]


def latest_version_gitlab(url: str, pattern: str) -> str | None:
    """Fetch tags from a GitLab project API."""
    api = url.rstrip("/") + "/-/refs?ref=&sort=&format=json&search="
    try:
        r = requests.get(api, timeout=15)
        r.raise_for_status()
        data = r.json()
        tags = [t["name"] for t in data.get("Tags", [])]
    except Exception:
        # Fallback: use public GitLab tags API
        project_path = url.split("gitlab.cern.ch/")[-1].rstrip("/")
        api2 = f"https://gitlab.cern.ch/api/v4/projects/{requests.utils.quote(project_path, safe='')}/repository/tags"
        try:
            r2 = requests.get(api2, timeout=15)
            r2.raise_for_status()
            tags = [t["name"] for t in r2.json()]
        except Exception as e:
            print(f"  WARNING: could not fetch GitLab tags for {url}: {e}", file=sys.stderr)
            return None
    versions = [re.search(pattern, t).group(1) for t in tags if re.search(pattern, t)]
    if not versions:
        return None
    from packaging.version import Version, InvalidVersion
    valid = [Version(v) for v in versions if _is_valid_version(v)]
    return str(max(valid)) if valid else versions[0]


def _is_valid_version(v: str) -> bool:
    from packaging.version import Version, InvalidVersion
    try:
        Version(v)
        return True
    except InvalidVersion:
        return False


def fetch_upstream(feedstock: str) -> str | None:
    if feedstock not in SOURCES:
        return None
    src = SOURCES[feedstock]
    if src["type"] == "html_scrape":
        return latest_version_html(src["url"], src["pattern"])
    elif src["type"] == "gitlab_tags":
        return latest_version_gitlab(src["url"], src.get("pattern", r"(\d+\.\d+\.\d+)"))
    elif src["type"] == "github_releases":
        repo = src["repo"]
        api = f"https://api.github.com/repos/{repo}/releases/latest"
        headers = {}
        if token := os.environ.get("GITHUB_TOKEN"):
            headers["Authorization"] = f"Bearer {token}"
        try:
            r = requests.get(api, headers=headers, timeout=15)
            r.raise_for_status()
            return r.json().get("tag_name", "").lstrip("v")
        except Exception as e:
            print(f"  WARNING: could not fetch GitHub releases for {repo}: {e}", file=sys.stderr)
            return None
    return None


def create_pr(feedstock: str, old_ver: str, new_ver: str) -> None:
    """Trigger bump_version.py, commit+push that change inside the feedstock's
    own repo (it's a separate git repo -- editing meta.yaml there does nothing
    until it's committed there), then open a meta-repo PR that bumps the
    submodule pointer to match."""
    bump_script = Path(__file__).parent / "bump_version.py"
    subprocess.run(
        [sys.executable, str(bump_script), feedstock, new_ver],
        check=True
    )
    submodule = f"feedstocks/{feedstock}-feedstock"
    submodule_path = REPO_ROOT / submodule

    default_branch = subprocess.run(
        ["git", "symbolic-ref", "--short", "HEAD"],
        cwd=submodule_path, check=True, capture_output=True, text=True,
    ).stdout.strip()
    subprocess.run(["git", "add", "recipe/meta.yaml"], cwd=submodule_path, check=True)
    subprocess.run(
        ["git", "commit", "-m", f"[hep-bot] bump to {new_ver}"],
        cwd=submodule_path, check=True,
    )
    subprocess.run(["git", "push", "origin", default_branch], cwd=submodule_path, check=True)

    branch = f"hep-bot/{feedstock}-{new_ver}"
    subprocess.run(["git", "checkout", "-b", branch], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "add", submodule], cwd=REPO_ROOT, check=True)
    subprocess.run(
        ["git", "commit", "-m", f"[hep-bot] {feedstock}: {old_ver} → {new_ver}"],
        cwd=REPO_ROOT, check=True
    )
    subprocess.run(["git", "push", "origin", branch], cwd=REPO_ROOT, check=True)
    subprocess.run([
        "gh", "pr", "create",
        "--title", f"[hep-bot] {feedstock}: {old_ver} → {new_ver}",
        "--body", f"Automated version bump: `{old_ver}` → `{new_ver}`\n\nTriggered by hep-bot weekly check.",
        "--head", branch,
    ], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "checkout", "main"], cwd=REPO_ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Print findings without creating PRs")
    args = parser.parse_args()

    for feedstock, info in DAG.items():
        if info.get("auto_update") is False:
            continue
        if feedstock not in SOURCES:
            continue

        current = current_version(feedstock)
        upstream = fetch_upstream(feedstock)

        if not current or not upstream:
            print(f"SKIP  {feedstock}: current={current!r} upstream={upstream!r}")
            continue

        if current == upstream:
            print(f"OK    {feedstock}: {current}")
        else:
            print(f"BUMP  {feedstock}: {current} → {upstream}")
            if not args.dry_run:
                create_pr(feedstock, current, upstream)


if __name__ == "__main__":
    main()
