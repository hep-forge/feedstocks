#!/usr/bin/env bash
# Print a status table for all feedstocks:
#   Name | Tags | Latest tag | Last AMD64 build | Last ARM64 build | Last macOS ARM64 build | Branches
#
# Feedstocks are on one of two CI schemes:
#   unified  - single .github/workflows/autoupload.yml, amd64+arm64+macos-arm64
#              build in one matrix job. A successful run implies all three
#              legs succeeded, so the same date is shown in all three columns.
#   legacy   - separate autoupload.amd64.yml / autoupload.arm64.yml, no macOS
#              build yet ("n/a" in that column until migrated).
#
# The BRANCHES column reads local remote-tracking refs (git branch -r),
# not a live GitHub query -- deliberately, to avoid a fetch per feedstock
# (56 network round-trips) on every invocation. If a branch was deleted
# upstream (e.g. via the GitHub API rather than a normal push/pull),
# your local clone won't know until pruned -- it'll keep showing the
# stale branch name forever. Run with --prune once after any upstream
# branch deletion/rename to clean the cache; otherwise skip it.
#
# Usage:
#   bash scripts/feedstock_status.sh
#   bash scripts/feedstock_status.sh fastjet   # single feedstock
#   bash scripts/feedstock_status.sh --prune   # also prune stale local
#                                               # remote-tracking branches first
#
# Requires: gh CLI authenticated as a hep-forge org member

set -euo pipefail
# Exit quietly (not a scary Make 'Error 141') if stdout closes early --
# piping into head/less and quitting, or an interrupted terminal.
trap 'exit 0' PIPE

FILTER=""
PRUNE=0
for arg in "$@"; do
  case "$arg" in
    --prune) PRUNE=1 ;;
    *)       FILTER="$arg" ;;
  esac
done
ORG="hep-forge"

cd "$(dirname "$0")/.."

# ANSI colors (disabled when not a terminal)
if [ -t 1 ]; then
  BOLD="\033[1m"
  DIM="\033[2m"
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  CYAN="\033[36m"
  RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

# Header
printf "${BOLD}${CYAN}%-35s  %-6s  %-20s  %-12s  %-12s  %-12s  %s${RESET}\n" \
  "FEEDSTOCK" "NTAGS" "LATEST TAG" "AMD64 BUILD" "ARM64 BUILD" "MACOS BUILD" "BRANCHES"
printf "${DIM}"
printf '%0.s-' {1..130}
printf "${RESET}\n"

for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue

  repo=$(basename "$dir")
  pkg="${repo%-feedstock}"

  if [ -n "$FILTER" ] && [ "$pkg" != "$FILTER" ] && [ "$repo" != "$FILTER" ]; then
    continue
  fi

  [ "$PRUNE" -eq 1 ] && git -C "$dir" remote prune origin >/dev/null 2>&1

  # All tags sorted by version descending
  all_tags=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null)
  if [ -z "$all_tags" ]; then
    ntags=0
  else
    ntags=$(printf '%s\n' "$all_tags" | wc -l | tr -d ' ')
  fi
  latest_tag=$(printf '%s\n' "$all_tags" | head -1)
  [ -z "$latest_tag" ] && latest_tag="(none)"

  # Last successful build date(s) (gh api failure → "never")
  if [ -e "$dir/.github/workflows/autoupload.yml" ]; then
    # Unified scheme: one workflow, 3-way matrix. A successful run implies
    # amd64 + arm64 + macos-arm64 all succeeded (publish needs all 3 legs).
    last_unified=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.yml/runs" \
      --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
      2>/dev/null | head -1 | cut -c1-10 || true)
    [ -z "$last_unified" ] && last_unified="never"
    last_amd64="$last_unified"
    last_arm64="$last_unified"
    last_macos="$last_unified"
  else
    last_amd64=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.amd64.yml/runs" \
      --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
      2>/dev/null | head -1 | cut -c1-10 || true)
    [ -z "$last_amd64" ] && last_amd64="never"

    last_arm64=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.arm64.yml/runs" \
      --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
      2>/dev/null | head -1 | cut -c1-10 || true)
    [ -z "$last_arm64" ] && last_arm64="never"

    last_macos="n/a"    # not migrated to the macos-arm64 matrix yet
  fi

  # Remote branches (each branch = one Anaconda label); strip origin/ prefix, exclude HEAD
  branches=$(git -C "$dir" branch -r --format='%(refname:short)' 2>/dev/null \
    | sed 's|^origin/||' | grep -v '^HEAD' | sort -u | tr '\n' ' ' | sed 's/ $//')
  [ -z "$branches" ] && branches="main"

  # Color each field based on value
  [ "$ntags"      = "0" ]     && c_ntags="${YELLOW}"   || c_ntags="${GREEN}"
  [ "$latest_tag" = "(none)" ] && c_tag="${YELLOW}"    || c_tag="${RESET}"
  [ "$last_amd64" = "never" ]  && c_amd64="${RED}"     || c_amd64="${GREEN}"
  [ "$last_arm64" = "never" ]  && c_arm64="${RED}"     || c_arm64="${GREEN}"
  case "$last_macos" in
    "never") c_macos="${RED}" ;;
    "n/a")   c_macos="${DIM}" ;;
    *)       c_macos="${GREEN}" ;;
  esac

  printf "%-35s  ${c_ntags}%-6s${RESET}  ${c_tag}%-20s${RESET}  ${c_amd64}%-12s${RESET}  ${c_arm64}%-12s${RESET}  ${c_macos}%-12s${RESET}  ${CYAN}%s${RESET}\n" \
    "$repo" "$ntags" "$latest_tag" "$last_amd64" "$last_arm64" "$last_macos" "$branches"
done
