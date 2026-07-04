#!/usr/bin/env bash
# Per-architecture CI status: for each feedstock show the LATEST
# autoupload run broken down by job -- amd64 build, arm64 build,
# publish -- plus which ref/event triggered it. ci_status.sh only shows
# the run-level conclusion, which hides *which leg* broke.
#
# Bot-friendly: plain columns when piped, exit 1 if any leg of any
# feedstock's latest run failed.
#
# Usage:
#   bash scripts/status_arch.sh                 # all feedstocks
#   bash scripts/status_arch.sh fastjet         # one feedstock
#   bash scripts/status_arch.sh --failed        # only rows with a red leg
#
# Requirements: gh CLI authenticated as a hep-forge org member

set -uo pipefail

ORG="hep-forge"
FILTER=""
FAILED_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --failed) FAILED_ONLY=1 ;;
    --*)      echo "Unknown flag: $arg"; exit 1 ;;
    *)        FILTER="$arg" ;;
  esac
done

cd "$(dirname "$0")/.."

if [ -t 1 ]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"
  YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

# Colorize a job conclusion into a fixed-width cell
cell() {
  local c="$1"
  case "$c" in
    success)             printf "${GREEN}%-9s${RESET}" "PASS" ;;
    failure)             printf "${RED}%-9s${RESET}" "FAIL" ;;
    skipped)             printf "${DIM}%-9s${RESET}" "skip" ;;
    cancelled)           printf "${YELLOW}%-9s${RESET}" "CANCEL" ;;
    "")                  printf "${DIM}%-9s${RESET}" "-" ;;
    *)                   printf "${YELLOW}%-9s${RESET}" "${c:0:9}" ;;
  esac
}

printf "${BOLD}${CYAN}%-28s %-9s %-9s %-9s %-19s %-17s %s${RESET}\n" \
  "FEEDSTOCK" "AMD64" "ARM64" "PUBLISH" "EVENT@REF" "STARTED" "RUN"
printf "${DIM}%0.s-" {1..120}
printf "${RESET}\n"

ANY_FAILED=0
ANY_RUNNING=0

for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue

  repo=$(basename "$dir")
  pkg="${repo%-feedstock}"

  if [ -n "$FILTER" ] && [ "$pkg" != "$FILTER" ] && [ "$repo" != "$FILTER" ]; then
    continue
  fi

  line=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.yml/runs?per_page=1" \
    --jq '.workflow_runs[0] | "\(.id)\t\(.status)\t\(.event)\t\(.head_branch)\t\(.run_started_at)"' \
    2>/dev/null || true)

  if [ -z "$line" ] || [ "$line" = "null" ]; then
    printf "%-28s ${DIM}%s${RESET}\n" "$pkg" "no runs"
    continue
  fi

  IFS=$'\t' read -r run_id status event ref started <<< "$line"
  started="${started:0:16}"
  url="https://github.com/$ORG/$repo/actions/runs/$run_id"

  # Per-job conclusions of that run (empty conclusion = still running)
  jobs=$(gh api "repos/$ORG/$repo/actions/runs/$run_id/jobs?per_page=30" \
    --jq '.jobs[] | "\(.name)\t\(.status)\t\(.conclusion)"' 2>/dev/null || true)

  amd64="" arm64="" publish=""
  while IFS=$'\t' read -r jname jstatus jconc; do
    [ -z "$jname" ] && continue
    [ "$jstatus" != "completed" ] && { jconc="running"; ANY_RUNNING=1; }
    case "$jname" in
      *amd64*)   amd64="$jconc" ;;
      *arm64*)   arm64="$jconc" ;;
      publish*)  publish="$jconc" ;;
    esac
  done <<< "$jobs"

  row_failed=0
  for c in "$amd64" "$arm64" "$publish"; do
    [ "$c" = "failure" ] && row_failed=1 && ANY_FAILED=1
  done

  if [ "$FAILED_ONLY" -eq 1 ] && [ "$row_failed" -eq 0 ]; then
    continue
  fi

  printf "%-28s " "$pkg"
  cell "$amd64"; printf " "
  cell "$arm64"; printf " "
  cell "$publish"; printf " "
  printf "%-19s %-17s ${DIM}%s${RESET}\n" "${event}@${ref}" "$started" "$url"
done

echo ""
if [ "$ANY_FAILED" -eq 1 ]; then
  printf "${RED}Some legs FAILED on the latest run.${RESET}\n"
  exit 1
elif [ "$ANY_RUNNING" -eq 1 ]; then
  printf "${YELLOW}No failures so far, but some runs are still in progress.${RESET}\n"
else
  printf "${GREEN}All legs green.${RESET}\n"
fi
