#!/usr/bin/env python3
"""
Keep the `root:` variant list in every downstream feedstock's
recipe/conda_build_config.yaml capped at the newest N (default 2) ROOT
versions, dropping the oldest. ROOT itself is manually versioned
(dag.yaml: auto_update: false) -- this is the helper you run by hand
when a new ROOT release should be rolled out to consumers.

Usage:
    python root_versions.py --trim                  # trim all consumers to newest 2, no new version
    python root_versions.py 6.40                    # add 6.40 everywhere, then trim to newest 2
    python root_versions.py 6.40 --keep 3            # custom cap
    python root_versions.py 6.40 --dry-run           # preview only, no commit/push
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parents[2]


def find_consumers():
    """Feedstocks whose conda_build_config.yaml has an active `root:` key."""
    return sorted((REPO_ROOT / "feedstocks").glob("*-feedstock/recipe/conda_build_config.yaml"))


def parse_root_block(lines):
    """Return (start, end, active_versions) for the root: block, or None if absent."""
    start = next((i for i, l in enumerate(lines) if re.match(r"^root:\s*$", l)), None)
    if start is None:
        return None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].strip() == "":
            end = i
            break
        if not lines[i].startswith((" ", "\t", "#")):
            end = i
            break
    versions = [
        m.group(1)
        for l in lines[start + 1 : end]
        if (m := re.match(r"^\s*-\s*([\d.]+)\s*$", l))
    ]
    return start, end, versions


def sort_key(v):
    return tuple(int(x) for x in v.split("."))


def update_file(path, new_version, keep, dry_run):
    lines = path.read_text().splitlines(keepends=True)
    block = parse_root_block(lines)
    if block is None:
        return None
    start, end, versions = block

    updated = list(versions)
    if new_version and new_version not in updated:
        updated.append(new_version)

    kept = sorted(set(updated), key=sort_key)[-keep:]
    dropped = [v for v in versions if v not in kept]
    added = [v for v in kept if v not in versions]

    if not added and not dropped:
        return None  # already exactly right, nothing to do

    new_block = ["root:\n"] + [f"  - {v}\n" for v in kept]
    new_lines = lines[:start] + new_block + lines[end:]

    if not dry_run:
        path.write_text("".join(new_lines))

    return kept, added, dropped


def push_branch(feedstock_dir):
    """Push HEAD to whatever the current/default branch is, working whether
    or not we're actually checked out on a named branch (mirrors
    check_versions.py's create_pr() handling of detached-HEAD checkouts)."""
    branch = subprocess.run(
        ["git", "symbolic-ref", "--short", "HEAD"],
        cwd=feedstock_dir, capture_output=True, text=True,
    ).stdout.strip()
    if not branch:
        symref = subprocess.run(
            ["git", "ls-remote", "--symref", "origin", "HEAD"],
            cwd=feedstock_dir, check=True, capture_output=True, text=True,
        ).stdout.splitlines()[0]
        branch = symref.split()[1].removeprefix("refs/heads/")
    subprocess.run(["git", "push", "origin", f"HEAD:refs/heads/{branch}"], cwd=feedstock_dir, check=True)
    return branch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("version", nargs="?", help="New ROOT version to add before trimming")
    parser.add_argument("--keep", type=int, default=2, help="How many versions to keep (default 2)")
    parser.add_argument("--trim", action="store_true", help="Only trim existing lists, don't add a version")
    parser.add_argument("--dry-run", action="store_true", help="Preview only, don't write/commit/push")
    args = parser.parse_args()

    if not args.version and not args.trim:
        parser.error("pass a version to add (e.g. 6.40) or --trim to just cap existing lists")

    changed = []
    for path in find_consumers():
        repo = path.parents[1].name
        result = update_file(path, args.version, args.keep, args.dry_run)
        if result is None:
            print(f"  {repo:30s} unchanged")
            continue
        kept, added, dropped = result
        bits = [f"kept={kept}"]
        if added:
            bits.append(f"added={added}")
        if dropped:
            bits.append(f"dropped={dropped}")
        print(f"  {repo:30s} {' '.join(bits)}")
        changed.append(path.parents[1])

    label = "would change" if args.dry_run else "changed"
    print(f"\n{len(changed)} feedstock(s) {label}.")
    if args.dry_run or not changed:
        return

    print("\nCommitting + pushing...")
    for feedstock_dir in changed:
        repo = feedstock_dir.name
        subprocess.run(["git", "add", "recipe/conda_build_config.yaml"], cwd=feedstock_dir, check=True)
        msg = f"[hep-bot] root: keep newest {args.keep}" + (f" (added {args.version})" if args.version else "")
        subprocess.run(["git", "commit", "-m", msg], cwd=feedstock_dir, check=True)
        branch = push_branch(feedstock_dir)
        print(f"  {repo}: pushed to {branch}")


if __name__ == "__main__":
    main()
