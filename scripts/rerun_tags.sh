#!/usr/bin/env bash
# Trigger rebuilds across feedstocks via workflow_dispatch.
#
# Two modes, differing in which ref the build checks out:
#
#   tag mode (default)   Dispatch at each feedstock's latest git tag.
#                        Rebuilds the RECIPE STATE AT THE TAG and uploads
#                        the clean tag version. Use to republish releases.
#                        NOTE: a tag predating recipe fixes rebuilds the
#                        broken recipe -- re-tag (move the tag to current
#                        HEAD) first if the recipe changed since tagging.
#
#   --main               Dispatch at each feedstock's default branch
#                        (main/master). Builds the CURRENT recipe with all
#                        fixes; the version gets a ".dev" suffix (see the
#                        env job in autoupload.yml). Use to validate that
#                        every feedstock builds green after recipe/CI
#                        changes, without touching tags.
#
# One tag  = one software release (uploaded to Anaconda with that version number)
# One branch = one Anaconda label (e.g. pythia main/legacy -> labels main/legacy)
#
# Usage:
#   bash scripts/rerun_tags.sh                # tag mode, all feedstocks
#   bash scripts/rerun_tags.sh fastjet        # tag mode, one feedstock
#   bash scripts/rerun_tags.sh --main         # default-branch mode, all
#   bash scripts/rerun_tags.sh --main fastjet # default-branch mode, one
#   bash scripts/rerun_tags.sh --dry-run      # print without triggering
#   bash scripts/rerun_tags.sh --amd64-only   # legacy scheme only: skip ARM64 jobs
#
# Requirements: gh CLI authenticated as a hep-forge org member

set -euo pipefail

DRY_RUN=0
FILTER=""
AMD64_ONLY=0
MAIN_MODE=0
ORG="hep-forge"
DELAY=3   # seconds between API calls (avoid rate-limiting)

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --amd64-only) AMD64_ONLY=1 ;;
    --main)       MAIN_MODE=1 ;;
    --*)          echo "Unknown flag: $arg"; exit 1 ;;
    *)            FILTER="$arg" ;;
  esac
done

trigger() {
  local repo="$1" ref="$2" workflow="$3"
  # Branch dispatches are gated in autoupload.yml (tag-only policy) and
  # must opt in via the debug input; tag dispatches need no input.
  local extra=()
  [ "$MAIN_MODE" -eq 1 ] && [ "$workflow" = "autoupload.yml" ] && extra=(-f debug=true)
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "  [dry-run] gh workflow run %-30s --repo %s/%s --ref %s %s\n" \
      "$workflow" "$ORG" "$repo" "$ref" "${extra[*]:-}"
  else
    printf "  → %-30s @ %s\n" "$workflow" "$ref"
    gh workflow run "$workflow" --repo "$ORG/$repo" --ref "$ref" "${extra[@]}" 2>&1 \
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

  if [ "$MAIN_MODE" -eq 1 ]; then
    # Default-branch mode: build current recipe state (".dev" version).
    ref=$(git -C "$dir" ls-remote --symref origin HEAD 2>/dev/null \
      | awk '/^ref:/{sub("refs/heads/","",$2); print $2}')
    [ -z "$ref" ] && ref=main
    printf "%-40s branch=%s\n" "$repo" "$ref"
  else
    # Tag mode: find the latest tag (searches ALL tags, not just ancestors of HEAD)
    ref=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null | head -1)
    if [ -z "$ref" ]; then
      printf "SKIP %-40s no tags\n" "$repo"
      SKIPPED=$((SKIPPED+1))
      continue
    fi
    printf "%-40s tag=%s\n" "$repo" "$ref"
  fi

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
