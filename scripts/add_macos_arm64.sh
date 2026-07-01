#!/usr/bin/env bash
# Migrate feedstocks from the legacy two-workflow CI scheme
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
#   bash scripts/add_macos_arm64.sh --all               # every feedstock not yet migrated
#   bash scripts/add_macos_arm64.sh --all --dry-run     # preview all
#
# After running, review the diff, commit, and push inside each feedstock
# yourself — this script never commits or pushes.

set -uo pipefail

cd "$(dirname "$0")/.."
TEMPLATE="scripts/templates/autoupload.yml"

DRY_RUN=0
ALL=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --all)     ALL=1 ;;
    --*) echo "Unknown flag: $arg"; exit 1 ;;
    *)   TARGET="$arg" ;;
  esac
done

[ -f "$TEMPLATE" ] || { echo "Missing template: $TEMPLATE"; exit 1; }
if [ "$ALL" -eq 0 ] && [ -z "$TARGET" ]; then
  echo "Usage: bash scripts/add_macos_arm64.sh [--dry-run] <feedstock>"
  echo "       bash scripts/add_macos_arm64.sh [--dry-run] --all"
  exit 1
fi

migrate_one() {
  local repo="$1" dir="feedstocks/$1"

  if [ ! -d "$dir" ]; then
    printf "%-35s SKIP (no such feedstock)\n" "$repo"
    return 0
  fi
  if [ -e "$dir/.github/workflows/autoupload.yml" ]; then
    printf "%-35s SKIP (already migrated)\n" "$repo"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "%-35s DRY-RUN would migrate\n" "$repo"
    return 0
  fi

  cp "$TEMPLATE" "$dir/.github/workflows/autoupload.yml"
  rm -f "$dir/.github/workflows/autoupload.amd64.yml" "$dir/.github/workflows/autoupload.arm64.yml"

  local cf="$dir/conda-forge.yml"
  if [ -f "$cf" ] && ! grep -q "osx_arm64" "$cf"; then
    python3 - "$cf" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

out = []
for line in lines:
    out.append(line)
    if line.startswith("build_platform:"):
        out.append("  osx_arm64: osx_arm64\n")
    if line.rstrip("\n") == "  linux_aarch64: github_actions":
        out.append("  osx_arm64: github_actions\n")

with open(path, "w") as f:
    f.writelines(out)
PYEOF
  fi

  printf "%-35s MIGRATED\n" "$repo"
}

if [ "$ALL" -eq 1 ]; then
  for dir in feedstocks/*-feedstock; do
    migrate_one "$(basename "$dir")"
  done
else
  repo="$TARGET"
  [[ "$repo" == *-feedstock ]] || repo="${repo}-feedstock"
  migrate_one "$repo"
fi

echo ""
echo "Review with: git -C feedstocks/<name> diff, then commit + push yourself."
