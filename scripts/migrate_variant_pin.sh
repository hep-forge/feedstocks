#!/usr/bin/env bash
# Safely retire a keystone package's old version-line(s) across every
# feedstock that pins them in conda_build_config.yaml -- e.g. moving
# every root: 6.34/6.36 consumer to root: 6.38 -- instead of just
# blocking the trim (see channel_packages.py's pinned_by()/trim()
# safety net, which this is the other half of).
#
# This script only edits conda_build_config.yaml and (with --yes)
# commits + pushes. It does NOT trigger any build -- that's the
# multi-hour part, kept explicit and separate:
#   gh workflow run hep-bot-rebuild.yml --repo hep-forge/<pkg>-feedstock \
#     -f root_package=<pkg>
# (requires scripts/hep_bot/dag.yaml to correctly list every affected
# feedstock as a transitive dependent of <pkg> -- see `make doctor <pkg>`'s
# "who pins a specific version-line of this package" section to check.)
#
# Usage:
#   bash scripts/migrate_variant_pin.sh root --to 6.38 --drop 6.34,6.36,6.32
#   bash scripts/migrate_variant_pin.sh root --to 6.38 --drop 6.34,6.36,6.32 --yes
#
# Dry-run by default (prints a diff per affected feedstock, changes
# nothing). --yes commits+pushes each edit to that feedstock's main.

set -uo pipefail
trap 'exit 0' PIPE

PKG=""
TO=""
DROP=""
YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --to)   TO="$2"; shift 2 ;;
    --drop) DROP="$2"; shift 2 ;;
    --yes)  YES=1; shift ;;
    --*)    echo "Unknown flag: $1"; exit 1 ;;
    *)      PKG="$1"; shift ;;
  esac
done

if [ -z "$PKG" ] || [ -z "$TO" ] || [ -z "$DROP" ]; then
  echo "Usage: bash scripts/migrate_variant_pin.sh <pkg> --to <version-line> --drop <line1,line2,...> [--yes]"
  exit 1
fi

cd "$(dirname "$0")/.."

if [ -t 1 ]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"
  YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

PKG="$PKG" TO="$TO" DROP="$DROP" YES="$YES" python3 <<'PYEOF'
import difflib, os, re, subprocess, sys
from pathlib import Path

PKG = os.environ["PKG"]
TO = os.environ["TO"]
DROP = set(os.environ["DROP"].split(","))
YES = os.environ["YES"] == "1"


def block_span(text, key):
    """Span of a top-level `key:` block's `- value` / `#  - value` lines
    (including blank lines inside it), or None if the key isn't present."""
    m = re.search(rf"^{re.escape(key)}:[ \t]*\n", text, re.MULTILINE)
    if not m:
        return None
    start, end = m.start(), m.end()
    for line in text[m.end():].splitlines(keepends=True):
        if re.match(r"^\s*$", line) or re.match(r"^\s*#?\s*-\s*", line):
            end += len(line)
            continue
        break
    return start, end


def values_in_block(text, start, end):
    """[(value, is_commented), ...] for every `- value` / `# - value` line."""
    out = []
    for line in text[start:end].splitlines():
        m = re.match(r"^(#)?\s*-\s*([^\s#]+)", line)
        if m:
            out.append((m.group(2), bool(m.group(1))))
    return out


def migrate_one(path: Path):
    text = path.read_text()
    span = block_span(text, PKG)
    if span is None:
        return None
    start, end = span
    values = values_in_block(text, start, end)
    active = {v for v, commented in values if not commented}
    if not (active & DROP):
        return None  # nothing to do -- doesn't currently pin a dropped line

    key_start = re.search(rf"^{re.escape(PKG)}:", text, re.MULTILINE).start()
    new_block = f"{PKG}:\n  - {TO}\n"
    new_text = text[:key_start] + new_block + text[end:]

    # zip_keys pairing (e.g. escalade: [libtorch, root]) -- if PKG is
    # paired with another key that has an already-commented alternate
    # value, promote that alternate the same way (mirrors how root-plus
    # was migrated: root 6.32->6.38 alongside libtorch 2.6.0->2.8.0).
    zk_span = block_span(new_text, "zip_keys")
    paired_key = None
    if zk_span:
        zk_text = new_text[zk_span[0]:zk_span[1]]
        groups = re.findall(r"-\s*-\s*(\S+)\s*\n\s*-\s*(\S+)", zk_text)
        for a, b in groups:
            if a == PKG:
                paired_key = b
            elif b == PKG:
                paired_key = a

    if paired_key:
        pspan = block_span(new_text, paired_key)
        if pspan:
            pvalues = values_in_block(new_text, *pspan)
            commented_alt = [v for v, c in pvalues if c]
            if commented_alt:
                pkey_start = re.search(rf"^{re.escape(paired_key)}:", new_text, re.MULTILINE).start()
                new_pblock = f"{paired_key}:\n  - {commented_alt[0]}\n"
                new_text = new_text[:pkey_start] + new_pblock + new_text[pspan[1]:]

    return text, new_text


affected = []
for f in sorted(Path(".").glob("feedstocks/*-feedstock/recipe/conda_build_config.yaml")):
    dep_pkg = f.parent.parent.name[: -len("-feedstock")]
    if dep_pkg == PKG:
        continue
    result = migrate_one(f)
    if result is not None:
        affected.append((dep_pkg, f, *result))

if not affected:
    print(f"Nothing currently pins {PKG} to {sorted(DROP)} -- nothing to migrate.")
    sys.exit(0)

print(f"{PKG}: migrating {len(affected)} feedstock(s) off {sorted(DROP)} -> {TO}\n")
for dep_pkg, f, old_text, new_text in affected:
    print(f"--- {dep_pkg} ({f}) ---")
    diff = difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile="before", tofile="after",
    )
    sys.stdout.writelines(diff)
    print()

if not YES:
    print(f"[dry-run] {len(affected)} feedstock(s) would be edited + committed + pushed. Rerun with --yes to apply.")
    sys.exit(0)

for dep_pkg, f, old_text, new_text in affected:
    f.write_text(new_text)
    repo_dir = f.parent.parent
    subprocess.run(["git", "-C", str(repo_dir), "add", "recipe/conda_build_config.yaml"], check=True)
    subprocess.run(
        ["git", "-C", str(repo_dir), "commit", "-m",
         f"Migrate {PKG} pin: {'/'.join(sorted(DROP))} -> {TO}"],
        check=True,
    )
    subprocess.run(["git", "-C", str(repo_dir), "push"], check=True)
    print(f"{dep_pkg}: committed + pushed.")

print(
    "\nRecipes updated. Nothing has been rebuilt yet -- trigger the DAG-ordered "
    f"rebuild explicitly when ready:\n"
    f"  gh workflow run hep-bot-rebuild.yml --repo hep-forge/{PKG}-feedstock -f root_package={PKG}"
)
PYEOF
