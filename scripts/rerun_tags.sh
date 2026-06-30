#!/usr/bin/env bash
# Trigger autoupload.amd64.yml and autoupload.arm64.yml for every feedstock
# that has a version-like tag (starting with a digit).
#
# Usage:
#   bash scripts/rerun_tags.sh           # trigger all feedstocks
#   bash scripts/rerun_tags.sh fastjet   # trigger one feedstock by name
#   bash scripts/rerun_tags.sh --dry-run # print what would run, don't trigger
#
# Requirements: gh CLI authenticated as a hep-forge org member

set -euo pipefail

DRY_RUN=0
FILTER=""
ORG="hep-forge"
DELAY=4   # seconds between API calls (avoid rate-limiting)

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --*) echo "Unknown flag: $arg"; exit 1 ;;
    *) FILTER="$arg" ;;
  esac
done

trigger() {
  local repo="$1" tag="$2" workflow="$3"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] gh workflow run $workflow --repo $ORG/$repo --ref $tag"
  else
    echo "  → triggering $workflow on $repo @ $tag"
    gh workflow run "$workflow" --repo "$ORG/$repo" --ref "$tag" 2>&1 \
      || echo "  WARNING: failed to trigger $workflow for $repo"
    sleep "$DELAY"
  fi
}

cd "$(dirname "$0")/.."

TRIGGERED=0
SKIPPED=0

for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue

  repo=$(basename "$dir")
  pkg="${repo%-feedstock}"

  # If a filter is given, skip non-matching feedstocks
  if [ -n "$FILTER" ] && [ "$pkg" != "$FILTER" ] && [ "$repo" != "$FILTER" ]; then
    continue
  fi

  # Find the latest tag
  tag=$(git -C "$dir" describe --tags --abbrev=0 2>/dev/null || echo "")

  if [ -z "$tag" ]; then
    echo "SKIP $repo — no tags"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  # Only version-like tags (starting with a digit) trigger proper version builds.
  # Tags like "master", "alpha", "v1.2.3" need manual intervention.
  if [[ ! "$tag" =~ ^[0-9] ]]; then
    echo "SKIP $repo — tag '$tag' does not start with a digit (not a version tag)"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  echo "$repo @ $tag"
  trigger "$repo" "$tag" "autoupload.amd64.yml"
  trigger "$repo" "$tag" "autoupload.arm64.yml"
  TRIGGERED=$((TRIGGERED+1))
done

echo ""
echo "Triggered: $TRIGGERED feedstocks"
echo "Skipped:   $SKIPPED feedstocks"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run — nothing was actually triggered)"
fi
