#!/usr/bin/env bash
# Show the LATEST workflow run per feedstock -- success, failure, or still
# running -- so broken builds are visible (feedstock_status.sh only shows
# the last *successful* build dates, silently hiding failures).
#
# Bot-friendly: plain columns when piped, exit code 1 if any feedstock's
# latest run failed, so it can gate automation (hep-bot, cron, CI).
#
# Usage:
#   bash scripts/ci_status.sh                 # all feedstocks
#   bash scripts/ci_status.sh fastjet         # one feedstock
#   bash scripts/ci_status.sh --failed        # only not-green rows
#
# Requirements: gh CLI authenticated as a hep-forge org member

set -uo pipefail
# Exit quietly (not a scary Make 'Error 141') if stdout closes early --
# piping into head/less and quitting, or an interrupted terminal.
trap 'exit 0' PIPE

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

printf "${BOLD}${CYAN}%-35s %-12s %-10s %-17s %s${RESET}\n" \
  "FEEDSTOCK" "RESULT" "REF" "STARTED" "RUN"
printf "${DIM}%0.s-" {1..100}
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
    --jq '.workflow_runs[0] | "\(.status)\t\(.conclusion)\t\(.head_branch)\t\(.run_started_at)\t\(.id)"' \
    2>/dev/null || true)

  if [ -z "$line" ] || [ "$line" = "null" ]; then
    printf "%-35s ${DIM}%-12s${RESET}\n" "$repo" "no runs"
    continue
  fi

  IFS=$'\t' read -r status conclusion branch started run_id <<< "$line"
  started="${started:0:16}"   # 2026-07-03T12:34
  url="https://github.com/$ORG/$repo/actions/runs/$run_id"

  case "$status" in
    completed)
      case "$conclusion" in
        success)
          [ "$FAILED_ONLY" -eq 1 ] && continue
          printf "%-35s ${GREEN}%-12s${RESET} %-10s %-17s ${DIM}%s${RESET}\n" \
            "$repo" "PASS" "$branch" "$started" "$url"
          ;;
        *)
          ANY_FAILED=1
          printf "%-35s ${RED}%-12s${RESET} %-10s %-17s %s\n" \
            "$repo" "${conclusion^^}" "$branch" "$started" "$url"
          ;;
      esac
      ;;
    *)
      ANY_RUNNING=1
      printf "%-35s ${YELLOW}%-12s${RESET} %-10s %-17s ${DIM}%s${RESET}\n" \
        "$repo" "${status^^}" "$branch" "$started" "$url"
      ;;
  esac
done

echo ""
if [ "$ANY_FAILED" -eq 1 ]; then
  printf "${RED}Some feedstocks' latest run FAILED.${RESET}\n"
  exit 1
elif [ "$ANY_RUNNING" -eq 1 ]; then
  printf "${YELLOW}No failures so far, but some runs are still in progress.${RESET}\n"
else
  printf "${GREEN}All latest runs green.${RESET}\n"
fi
