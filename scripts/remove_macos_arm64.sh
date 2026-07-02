#!/usr/bin/env bash
# Reverse of add_macos_arm64.sh: drop the macos-arm64 leg from the CI
# matrix (scripts/templates/autoupload.yml) and reapply across
# feedstocks, since macOS conda builds turned out to be unnecessary --
# Docker on Apple Silicon already runs linux-arm64 containers natively.
#
# This only touches CI plumbing (workflow file + conda-forge.yml
# provider/build_platform osx_arm64 entries). Recipe-level portability
# fixes (gnuconfig, portable nproc, etc.) stay -- they're still needed
# for linux-arm64 and are harmless on linux-amd64.
#
# Usage:
#   bash scripts/remove_macos_arm64.sh fastjet            # one feedstock
#   bash scripts/remove_macos_arm64.sh --dry-run fastjet   # show, don't write
#   bash scripts/remove_macos_arm64.sh --all               # every feedstock with the macos leg
#   bash scripts/remove_macos_arm64.sh --all --dry-run     # preview all
#
# After running, review the diff, commit, and push inside each feedstock
# yourself -- this script never commits or pushes.

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
  echo "Usage: bash scripts/remove_macos_arm64.sh [--dry-run] <feedstock>"
  echo "       bash scripts/remove_macos_arm64.sh [--dry-run] --all"
  exit 1
fi

revert_one() {
  local repo="$1" dir="feedstocks/$1"
  local wf="$dir/.github/workflows/autoupload.yml"

  if [ ! -d "$dir" ]; then
    printf "%-35s SKIP (no such feedstock)\n" "$repo"
    return 0
  fi
  if [ ! -e "$wf" ]; then
    printf "%-35s SKIP (no unified workflow)\n" "$repo"
    return 0
  fi
  if ! grep -q "macos-arm64" "$wf"; then
    printf "%-35s SKIP (already 2-way)\n" "$repo"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "%-35s DRY-RUN would revert\n" "$repo"
    return 0
  fi

  cp "$TEMPLATE" "$wf"

  local cf="$dir/conda-forge.yml"
  if [ -f "$cf" ]; then
    python3 - "$cf" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

out = [l for l in lines if l.strip() not in ("osx_arm64: osx_arm64", "osx_arm64: github_actions")]

with open(path, "w") as f:
    f.writelines(out)
PYEOF
  fi

  printf "%-35s REVERTED\n" "$repo"
}

if [ "$ALL" -eq 1 ]; then
  for dir in feedstocks/*-feedstock; do
    revert_one "$(basename "$dir")"
  done
else
  repo="$TARGET"
  [[ "$repo" == *-feedstock ]] || repo="${repo}-feedstock"
  revert_one "$repo"
fi

echo ""
echo "Review with: git -C feedstocks/<name> diff, then commit + push yourself."
