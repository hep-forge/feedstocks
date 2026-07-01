#!/usr/bin/env python3
"""
Keep a named variant key's version list (e.g. `root:`, `libtorch:`) in
every downstream feedstock's recipe/conda_build_config.yaml capped at the
newest N versions, dropping the oldest. Some variant keys are zip_keys-
paired with another key (positional pairing -- root[i] always builds
against libtorch[i]); when the target key is zip-paired, the whole group
is trimmed/extended together so the pairing stays valid.

ROOT itself is manually versioned (dag.yaml: auto_update: false) -- this
is the semi-automated helper you run by hand when a new release of
whatever the key tracks should be rolled out to consumers.

Usage:
    python variant_versions.py --key root --trim                # cap all consumers at newest 2
    python variant_versions.py --key root 6.40                   # add 6.40, then trim to newest 2
    python variant_versions.py --key root 6.40 --keep 3           # custom cap
    python variant_versions.py --key root 6.40 --pair libtorch=2.8.0   # zip-paired key needs an explicit value
    python variant_versions.py --key root 6.40 --dry-run          # preview only, no commit/push
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).parents[2]


def find_consumers(key):
    """Feedstocks whose conda_build_config.yaml has an active `<key>:` list."""
    out = []
    for path in sorted((REPO_ROOT / "feedstocks").glob("*-feedstock/recipe/conda_build_config.yaml")):
        if re.search(rf"^{re.escape(key)}:\s*$", path.read_text(), re.M):
            out.append(path)
    return out


def zip_group(path, key):
    """Other keys `key` is zip_keys-paired with (positional pairing), or []."""
    try:
        data = yaml.safe_load(path.read_text()) or {}
    except yaml.YAMLError:
        return []
    for group in data.get("zip_keys", []) or []:
        if isinstance(group, list) and key in group:
            return [k for k in group if k != key]
    return []


def parse_list_block(lines, key):
    """Return (start, end, active_values) for `<key>:` block, or None if absent."""
    start = next((i for i, l in enumerate(lines) if re.match(rf"^{re.escape(key)}:\s*$", l)), None)
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
    values = [
        m.group(1)
        for l in lines[start + 1 : end]
        if (m := re.match(r"^\s*-\s*(\S.*?)\s*$", l))
    ]
    return start, end, values


def sort_key(v):
    try:
        return tuple(int(x) for x in v.split("."))
    except ValueError:
        return (v,)


def replace_list_block(lines, key, values):
    block = parse_list_block(lines, key)
    if block is None:
        raise ValueError(f"{key}: block not found")
    start, end, _ = block
    new_block = [f"{key}:\n"] + [f"  - {v}\n" for v in values]
    return lines[:start] + new_block + lines[end:]


def update_file(path, key, new_value, pairs, keep, dry_run):
    lines = path.read_text().splitlines(keepends=True)
    block = parse_list_block(lines, key)
    if block is None:
        return None
    _, _, primary = block

    paired_keys = zip_group(path, key)
    paired_lists = {}
    for pk in paired_keys:
        pb = parse_list_block(lines, pk)
        if pb is None:
            print(f"  WARNING: {path.parents[1].name}: zip-paired key '{pk}' has no list, skipping", file=sys.stderr)
            return None
        paired_lists[pk] = pb[2]

    if paired_keys and any(len(v) != len(primary) for v in paired_lists.values()):
        print(f"  WARNING: {path.parents[1].name}: {key} and {paired_keys} lengths don't match, skipping", file=sys.stderr)
        return None

    # (primary_value, {paired_key: paired_value}) tuples, positionally aligned
    rows = [
        (primary[i], {pk: paired_lists[pk][i] for pk in paired_keys})
        for i in range(len(primary))
    ]

    if new_value and new_value not in primary:
        if paired_keys and set(pairs) != set(paired_keys):
            raise ValueError(
                f"{key} is zip-paired with {paired_keys}; pass --pair for each "
                f"(e.g. {' '.join(f'--pair {k}=<value>' for k in paired_keys)})"
            )
        rows.append((new_value, dict(pairs)))

    seen = set()
    deduped = []
    for row in rows:
        if row[0] in seen:
            continue
        seen.add(row[0])
        deduped.append(row)
    rows_sorted = sorted(deduped, key=lambda r: sort_key(r[0]))
    kept_rows = rows_sorted[-keep:]
    kept_primary = [r[0] for r in kept_rows]
    dropped = [v for v in primary if v not in kept_primary]
    added = [v for v in kept_primary if v not in primary]

    if not added and not dropped:
        return None

    new_lines = replace_list_block(lines, key, kept_primary)
    for pk in paired_keys:
        pk_values = [r[1][pk] for r in kept_rows]
        new_lines = replace_list_block(new_lines, pk, pk_values)

    if not dry_run:
        path.write_text("".join(new_lines))

    return kept_primary, added, dropped, paired_keys


def push_branch(feedstock_dir):
    """Push HEAD to whatever the current/default branch is, working whether
    or not we're actually checked out on a named branch."""
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
    parser.add_argument("--key", required=True, help="Variant key to manage, e.g. root, libtorch")
    parser.add_argument("version", nargs="?", help="New version to add before trimming")
    parser.add_argument("--pair", action="append", default=[], metavar="KEY=VALUE",
                         help="Value for a zip-paired key when adding a new version (repeatable)")
    parser.add_argument("--keep", type=int, default=2, help="How many versions to keep (default 2)")
    parser.add_argument("--trim", action="store_true", help="Only trim existing lists, don't add a version")
    parser.add_argument("--dry-run", action="store_true", help="Preview only, don't write/commit/push")
    args = parser.parse_args()

    if not args.version and not args.trim:
        parser.error("pass a version to add (e.g. 6.40) or --trim to just cap existing lists")

    pairs = dict(p.split("=", 1) for p in args.pair)

    changed = []
    for path in find_consumers(args.key):
        repo = path.parents[1].name
        try:
            result = update_file(path, args.key, args.version, pairs, args.keep, args.dry_run)
        except ValueError as e:
            print(f"  {repo:30s} ERROR: {e}", file=sys.stderr)
            continue
        if result is None:
            print(f"  {repo:30s} unchanged")
            continue
        kept, added, dropped, paired_keys = result
        bits = [f"kept={kept}"]
        if added:
            bits.append(f"added={added}")
        if dropped:
            bits.append(f"dropped={dropped}")
        if paired_keys:
            bits.append(f"(zip-paired with {paired_keys})")
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
        msg = f"[hep-bot] {args.key}: keep newest {args.keep}" + (f" (added {args.version})" if args.version else "")
        subprocess.run(["git", "commit", "-m", msg], cwd=feedstock_dir, check=True)
        branch = push_branch(feedstock_dir)
        print(f"  {repo}: pushed to {branch}")


if __name__ == "__main__":
    main()
