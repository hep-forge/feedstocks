#!/usr/bin/env bash
# Print a status table for all feedstocks:
#   Name | Tags (count + latest) | Branches | Last amd64 build
#
# Usage:
#   bash scripts/feedstock_status.sh
#   bash scripts/feedstock_status.sh fastjet   # single feedstock
#
# Requires: gh CLI authenticated as a hep-forge org member

set -euo pipefail

FILTER="${1:-}"
ORG="hep-forge"

cd "$(dirname "$0")/.."

# Header
printf "%-35s  %-6s  %-20s  %-30s  %s\n" \
  "FEEDSTOCK" "NTAGS" "LATEST TAG" "BRANCHES" "LAST AMD64 BUILD"
printf '%0.s-' {1..120}; echo

for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue

  repo=$(basename "$dir")
  pkg="${repo%-feedstock}"

  if [ -n "$FILTER" ] && [ "$pkg" != "$FILTER" ] && [ "$repo" != "$FILTER" ]; then
    continue
  fi

  # All tags sorted by version descending
  all_tags=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null)
  ntags=$(echo "$all_tags" | grep -c . || echo 0)
  latest_tag=$(echo "$all_tags" | head -1)
  [ -z "$latest_tag" ] && latest_tag="(none)"

  # All local branches (exclude HEAD)
  branches=$(git -C "$dir" branch --format='%(refname:short)' 2>/dev/null \
    | grep -v '^HEAD' | tr '\n' ' ' | sed 's/ $//')
  [ -z "$branches" ] && branches="main"

  # Last successful amd64 workflow run via GitHub API
  last_run=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.amd64.yml/runs" \
    --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
    2>/dev/null | head -1 | cut -c1-10 || echo "never")
  [ -z "$last_run" ] && last_run="never"

  printf "%-35s  %-6s  %-20s  %-30s  %s\n" \
    "$repo" "$ntags" "$latest_tag" "$branches" "$last_run"
done
