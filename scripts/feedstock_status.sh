#!/usr/bin/env bash
# Print a status table for all feedstocks:
#   Name | Tags | Latest tag | Last AMD64 build | Last ARM64 build | Branches
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
printf "%-35s  %-6s  %-20s  %-12s  %-12s  %s\n" \
  "FEEDSTOCK" "NTAGS" "LATEST TAG" "AMD64 BUILD" "ARM64 BUILD" "BRANCHES"
printf '%0.s-' {1..115}; echo

for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue

  repo=$(basename "$dir")
  pkg="${repo%-feedstock}"

  if [ -n "$FILTER" ] && [ "$pkg" != "$FILTER" ] && [ "$repo" != "$FILTER" ]; then
    continue
  fi

  # All tags sorted by version descending
  all_tags=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null)
  if [ -z "$all_tags" ]; then
    ntags=0
  else
    ntags=$(printf '%s\n' "$all_tags" | wc -l | tr -d ' ')
  fi
  latest_tag=$(printf '%s\n' "$all_tags" | head -1)
  [ -z "$latest_tag" ] && latest_tag="(none)"

  # Last successful run for each workflow (gh api failure → "never")
  last_amd64=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.amd64.yml/runs" \
    --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
    2>/dev/null | head -1 | cut -c1-10 || true)
  [ -z "$last_amd64" ] && last_amd64="never"

  last_arm64=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.arm64.yml/runs" \
    --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
    2>/dev/null | head -1 | cut -c1-10 || true)
  [ -z "$last_arm64" ] && last_arm64="never"

  # Remote branches (each branch = one Anaconda label); strip origin/ prefix, exclude HEAD
  branches=$(git -C "$dir" branch -r --format='%(refname:short)' 2>/dev/null \
    | sed 's|^origin/||' | grep -v '^HEAD' | sort -u | tr '\n' ' ' | sed 's/ $//')
  [ -z "$branches" ] && branches="main"

  printf "%-35s  %-6s  %-20s  %-12s  %-12s  %s\n" \
    "$repo" "$ntags" "$latest_tag" "$last_amd64" "$last_arm64" "$branches"
done
