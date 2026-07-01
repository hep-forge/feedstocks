#!/usr/bin/env bash
# Migrate one feedstock from the legacy two-workflow CI scheme
# (autoupload.amd64.yml + autoupload.arm64.yml) to the unified 3-way
# matrix workflow (scripts/templates/autoupload.yml), which builds
# amd64 + linux-arm64 + macos-arm64 in parallel and shows them as three
# branches in a single Actions run graph.
#
# This only touches CI plumbing. It does NOT fix per-package build
# issues that a real macOS build might surface (e.g. `nproc` not existing
# on macOS, CMake/compiler version gaps in conda_build_config.yaml) —
# see feedstocks/cubature-feedstock for a worked example of both the CI
# migration and the recipe fixes it needed.
#
# Usage:
#   bash scripts/add_macos_arm64.sh fastjet            # one feedstock
#   bash scripts/add_macos_arm64.sh fastjet-feedstock   # same thing
#   bash scripts/add_macos_arm64.sh --dry-run fastjet   # show, don't write
#
# After running, review the diff, commit, and push inside the feedstock
# yourself — this script never commits or pushes.

set -euo pipefail

cd "$(dirname "$0")/.."
TEMPLATE="scripts/templates/autoupload.yml"

DRY_RUN=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --*) echo "Unknown flag: $arg"; exit 1 ;;
    *)   TARGET="$arg" ;;
  esac
done

[ -z "$TARGET" ] && { echo "Usage: bash scripts/add_macos_arm64.sh [--dry-run] <feedstock>"; exit 1; }
[ -f "$TEMPLATE" ] || { echo "Missing template: $TEMPLATE"; exit 1; }

repo="$TARGET"
[[ "$repo" == *-feedstock ]] || repo="${repo}-feedstock"
dir="feedstocks/$repo"

[ -d "$dir" ] || { echo "No such feedstock: $dir"; exit 1; }

if [ -e "$dir/.github/workflows/autoupload.yml" ]; then
  echo "SKIP $repo: already on the unified autoupload.yml scheme"
  exit 0
fi

echo "=== $repo ==="

if [ "$DRY_RUN" -eq 1 ]; then
  echo "  [dry-run] would write $dir/.github/workflows/autoupload.yml"
  [ -e "$dir/.github/workflows/autoupload.amd64.yml" ] && echo "  [dry-run] would remove $dir/.github/workflows/autoupload.amd64.yml"
  [ -e "$dir/.github/workflows/autoupload.arm64.yml" ] && echo "  [dry-run] would remove $dir/.github/workflows/autoupload.arm64.yml"
  echo "  [dry-run] would add osx_arm64 to $dir/conda-forge.yml"
  exit 0
fi

cp "$TEMPLATE" "$dir/.github/workflows/autoupload.yml"
rm -f "$dir/.github/workflows/autoupload.amd64.yml" "$dir/.github/workflows/autoupload.arm64.yml"
echo "  wrote .github/workflows/autoupload.yml (removed the amd64/arm64 pair)"

cf="$dir/conda-forge.yml"
if [ -f "$cf" ] && ! grep -q "osx_arm64" "$cf"; then
  python3 - "$cf" <<'PYEOF'
import sys, io

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

out = []
for i, line in enumerate(lines):
    out.append(line)
    if line.startswith("build_platform:"):
        out.append("  osx_arm64: osx_arm64\n")
    if line.rstrip("\n") == "  linux_aarch64: github_actions":
        out.append("  osx_arm64: github_actions\n")

with open(path, "w") as f:
    f.writelines(out)
PYEOF
  echo "  added osx_arm64 to conda-forge.yml"
fi

echo "  done -- review with: cd $dir && git diff"
