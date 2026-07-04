#!/usr/bin/env bash
# Trigger rebuilds across feedstocks via workflow_dispatch AT THE LATEST
# TAG. Builds only run on tag refs (autoupload.yml gates on
# github.ref_type == 'tag'); there is no branch/dev-build mode anymore.
#
# This rebuilds the RECIPE STATE AT THE TAG and uploads the clean tag
# version. A tag predating recipe fixes rebuilds the broken recipe --
# use scripts/retag_all.sh (make retag <name>) to move the tag to the
# current branch tip first; that is the standard rebuild path.
#
# NOTE: dispatching only works if the workflow file AT THE TAG already
# has the workflow_dispatch trigger; old tags fail with "No event
# triggers defined in `on`". retag_all.sh does not have that problem.
#
# One tag  = one software release (uploaded to Anaconda with that version number)
# One branch = one Anaconda label (main -> label main)
#
# Usage:
#   bash scripts/rerun_tags.sh                # all feedstocks
#   bash scripts/rerun_tags.sh fastjet        # one feedstock
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

  # Latest tag, preferring numeric ones -- the only kind the push
  # trigger accepts, and the only kind the dispatch gate lets build.
  ref=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null | grep '^[0-9]' | head -1)
  [ -z "$ref" ] && ref=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null | head -1)
  if [ -z "$ref" ]; then
    printf "SKIP %-40s no tags\n" "$repo"
    SKIPPED=$((SKIPPED+1))
    continue
  fi
  printf "%-40s tag=%s\n" "$repo" "$ref"

  if [ -e "$dir/.github/workflows/autoupload.yml" ]; then
    # Unified scheme: one dispatch builds amd64 + arm64 in parallel.
    trigger "$repo" "$ref" "autoupload.yml"
  else
    trigger "$repo" "$ref" "autoupload.amd64.yml"
    [ "$AMD64_ONLY" -eq 0 ] && trigger "$repo" "$ref" "autoupload.arm64.yml"
  fi
  TRIGGERED=$((TRIGGERED+1))
done

echo ""
echo "Triggered: $TRIGGERED feedstocks"
echo "Skipped:   $SKIPPED feedstocks"
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run — nothing was actually triggered)" || true
