#!/usr/bin/env bash
# Move each feedstock's latest version tag to the tip of its default
# branch and force-push it. Pushing the tag fires the autoupload
# workflow's push-tags trigger, so this IS the rebuild mechanism under
# the tag-only policy.
#
# Why not workflow_dispatch at the tag? Dispatch reads the workflow file
# AT THE DISPATCHED REF: tags that predate the current autoupload.yml
# fail with "No event triggers defined in `on`" / "Workflow does not
# have 'workflow_dispatch' trigger". Re-tagging updates the snapshot
# (workflow + recipe fixes) and triggers the build in one step.
#
# A tag already pointing at the branch tip is NOT pushed (no-op for
# git); pass --dispatch to rebuild those via workflow_dispatch at the
# tag ref instead -- safe there, since the tag content is current.
#
# Usage:
#   bash scripts/retag_all.sh --dry-run          # preview everything
#   bash scripts/retag_all.sh fastjet            # one feedstock
#   bash scripts/retag_all.sh --dispatch         # also re-fire up-to-date tags
#   bash scripts/retag_all.sh pkg1 pkg2 ...      # a specific set, in order
#
# Requirements: gh CLI authenticated as a hep-forge org member,
# push access to the feedstock repos.

set -uo pipefail

ORG="hep-forge"
DRY_RUN=0
DISPATCH=0
TARGETS=()
DELAY=3

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=1 ;;
    --dispatch) DISPATCH=1 ;;
    --*)        echo "Unknown flag: $arg"; exit 1 ;;
    *)          TARGETS+=("$arg") ;;
  esac
done

cd "$(dirname "$0")/.."

if [ ${#TARGETS[@]} -eq 0 ]; then
  for dir in feedstocks/*-feedstock; do
    [ -e "$dir/.git" ] || continue
    TARGETS+=("$(basename "$dir" | sed 's/-feedstock$//')")
  done
fi

RETAGGED=0
DISPATCHED=0
SKIPPED=0

for pkg in "${TARGETS[@]}"; do
  repo="${pkg%-feedstock}-feedstock"
  dir="feedstocks/$repo"
  [ -e "$dir/.git" ] || { echo "SKIP $pkg (no such feedstock)"; SKIPPED=$((SKIPPED+1)); continue; }

  git -C "$dir" fetch -q origin --tags --force 2>/dev/null

  tag=$(git -C "$dir" tag --sort=-v:refname | head -1)
  if [ -z "$tag" ]; then
    printf "SKIP %-30s no tags\n" "$pkg"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  branch=$(git -C "$dir" ls-remote --symref origin HEAD 2>/dev/null \
    | awk '/^ref:/{sub("refs/heads/","",$2); print $2}')
  branch="${branch:-main}"
  head=$(git -C "$dir" rev-parse "origin/$branch" 2>/dev/null)
  at=$(git -C "$dir" rev-parse "$tag^{commit}" 2>/dev/null)

  if [ "$head" = "$at" ]; then
    if [ "$DISPATCH" -eq 1 ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf "DISPATCH %-26s tag=%s (up to date) [dry-run]\n" "$pkg" "$tag"
      else
        printf "DISPATCH %-26s tag=%s (up to date)\n" "$pkg" "$tag"
        gh workflow run autoupload.yml --repo "$ORG/$repo" --ref "$tag" \
          || echo "  WARNING: dispatch failed for $repo"
        sleep "$DELAY"
      fi
      DISPATCHED=$((DISPATCHED+1))
    else
      printf "OK   %-30s tag=%s already at %s tip\n" "$pkg" "$tag" "$branch"
      SKIPPED=$((SKIPPED+1))
    fi
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "RETAG %-29s %s: %s -> %s [dry-run]\n" "$pkg" "$tag" "${at:0:7}" "${head:0:7}"
  else
    printf "RETAG %-29s %s: %s -> %s\n" "$pkg" "$tag" "${at:0:7}" "${head:0:7}"
    git -C "$dir" tag -f "$tag" "$head" >/dev/null \
      && git -C "$dir" push -q --force origin "refs/tags/$tag" \
      || { echo "  WARNING: retag failed for $repo"; continue; }
    sleep "$DELAY"
  fi
  RETAGGED=$((RETAGGED+1))
done

echo ""
echo "Retagged:   $RETAGGED (tag build fires via push trigger)"
echo "Dispatched: $DISPATCHED"
echo "Skipped:    $SKIPPED"
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run — nothing was pushed or dispatched)" || true
