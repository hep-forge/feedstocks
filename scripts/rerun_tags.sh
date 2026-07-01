#!/usr/bin/env bash
# Trigger a rebuild for every feedstock that has at least one git tag
# (the tag is the package version).
#
# Feedstocks migrated to the unified 3-way matrix workflow
# (.github/workflows/autoupload.yml) get ONE dispatch that builds
# amd64 + linux-arm64 + macos-arm64 in parallel. Feedstocks still on the
# legacy scheme get autoupload.amd64.yml and autoupload.arm64.yml
# triggered separately (also in parallel — GitHub runs dispatched
# workflows concurrently regardless).
#
# One tag  = one software release (uploaded to Anaconda with that version number)
# One branch = one Anaconda label (e.g. pythia main/6.x/8.x → labels main/6/8)
#
# Usage:
#   bash scripts/rerun_tags.sh                # trigger all feedstocks
#   bash scripts/rerun_tags.sh fastjet        # trigger one feedstock
#   bash scripts/rerun_tags.sh --dry-run      # print without triggering
#   bash scripts/rerun_tags.sh --amd64-only   # legacy scheme only: skip ARM64 jobs
#
# Requirements: gh CLI authenticated as a hep-forge org member

set -euo pipefail

DRY_RUN=0
FILTER=""
AMD64_ONLY=0
ORG="hep-forge"
DELAY=3   # seconds between API calls (avoid rate-limiting)

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --amd64-only) AMD64_ONLY=1 ;;
    --*)          echo "Unknown flag: $arg"; exit 1 ;;
    *)            FILTER="$arg" ;;
  esac
done

trigger() {
  local repo="$1" ref="$2" workflow="$3"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "  [dry-run] gh workflow run %-30s --repo %s/%s --ref %s\n" \
      "$workflow" "$ORG" "$repo" "$ref"
  else
    printf "  → %-30s @ %s\n" "$workflow" "$ref"
    gh workflow run "$workflow" --repo "$ORG/$repo" --ref "$ref" 2>&1 \
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

  if [ -n "$FILTER" ] && [ "$pkg" != "$FILTER" ] && [ "$repo" != "$FILTER" ]; then
    continue
  fi

  # Find the latest tag (searches ALL tags, not just ancestors of HEAD)
  tag=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null | head -1)

  if [ -z "$tag" ]; then
    printf "SKIP %-40s no tags\n" "$repo"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  printf "%-40s tag=%s\n" "$repo" "$tag"
  if [ -e "$dir/.github/workflows/autoupload.yml" ]; then
    # Unified scheme: one dispatch builds amd64 + arm64 + macos-arm64 in parallel.
    trigger "$repo" "$tag" "autoupload.yml"
  else
    trigger "$repo" "$tag" "autoupload.amd64.yml"
    [ "$AMD64_ONLY" -eq 0 ] && trigger "$repo" "$tag" "autoupload.arm64.yml"
  fi
  TRIGGERED=$((TRIGGERED+1))
done

echo ""
echo "Triggered: $TRIGGERED feedstocks"
echo "Skipped:   $SKIPPED feedstocks (no tags)"
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run — nothing was actually triggered)"
