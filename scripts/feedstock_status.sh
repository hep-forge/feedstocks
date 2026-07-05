#!/usr/bin/env bash
# One status table per feedstock: tags, the latest CI run broken down
# by job (amd64 / arm64 / publish), what triggered it, and branches.
#
# A job cell shows the LATEST run's outcome (PASS/FAIL/skip/RUNNING).
# If a leg FAILED, the cell also shows the date it last passed (e.g.
# "FAIL(ok 06-20)") -- otherwise "FAIL" alone doesn't tell you whether
# this is a fresh break or a week-old one.
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
#   bash scripts/feedstock_status.sh fastjet    # single feedstock
#   bash scripts/feedstock_status.sh --prune    # also prune stale local
#                                                # remote-tracking branches first
#   bash scripts/feedstock_status.sh --failed   # only rows with a red leg
#   VERBOSE=1 bash scripts/feedstock_status.sh  # also print each run's URL
#
# Requirements: gh CLI authenticated as a hep-forge org member

set -uo pipefail
# Exit quietly (not a scary Make 'Error 141') if stdout closes early --
# piping into head/less and quitting, or an interrupted terminal.
trap 'exit 0' PIPE

ORG="hep-forge"
FILTER=""
PRUNE=0
FAILED_ONLY=0
VERBOSE="${VERBOSE:-0}"

for arg in "$@"; do
  case "$arg" in
    --prune)  PRUNE=1 ;;
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

# Colorize a job conclusion into a fixed-width cell, appending a dim
# "(ok <date>)" note on failure if we have a last-known-good date.
cell() {
  local c="$1" last_ok="$2" label
  case "$c" in
    success)   printf "${GREEN}%-16s${RESET}" "PASS" ;;
    failure)
      if [ -n "$last_ok" ] && [ "$last_ok" != "never" ]; then
        label="FAIL(ok ${last_ok:5})"
      else
        label="FAIL"
      fi
      printf "${RED}%-16s${RESET}" "$label"
      ;;
    skipped)   printf "${DIM}%-16s${RESET}" "skip" ;;
    cancelled) printf "${YELLOW}%-16s${RESET}" "CANCEL" ;;
    running)   printf "${YELLOW}%-16s${RESET}" "RUNNING" ;;
    "")        printf "${DIM}%-16s${RESET}" "-" ;;
    *)         printf "${YELLOW}%-16s${RESET}" "${c:0:16}" ;;
  esac
}

printf "${BOLD}${CYAN}%-30s  %-5s  %-14s  %-16s %-16s %-16s %-19s  %s${RESET}\n" \
  "FEEDSTOCK" "NTAGS" "LATEST TAG" "AMD64" "ARM64" "PUBLISH" "TRIGGER@REF" "BRANCHES"
printf "${DIM}"
printf '%0.s-' {1..150}
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

  # Remote branches (each branch = one Anaconda label); strip origin/ prefix, exclude HEAD
  branches=$(git -C "$dir" branch -r --format='%(refname:short)' 2>/dev/null \
    | sed 's|^origin/||' | grep -v '^HEAD' | sort -u | tr '\n' ' ' | sed 's/ $//')
  [ -z "$branches" ] && branches="main"

  # Latest run + its per-job breakdown
  line=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.yml/runs?per_page=1" \
    --jq '.workflow_runs[0] | "\(.id)\t\(.status)\t\(.event)\t\(.head_branch)"' \
    2>/dev/null || true)

  if [ -z "$line" ] || [ "$line" = "null" ]; then
    [ "$FAILED_ONLY" -eq 1 ] && continue
    printf "%-30s  ${c_ntags:-}%-5s${RESET}  %-14s  ${DIM}%s${RESET}\n" \
      "$repo" "$ntags" "$latest_tag" "no runs"
    continue
  fi

  IFS=$'\t' read -r run_id status event ref <<< "$line"
  url="https://github.com/$ORG/$repo/actions/runs/$run_id"

  jobs=$(gh api "repos/$ORG/$repo/actions/runs/$run_id/jobs?per_page=30" \
    --jq '.jobs[] | "\(.name)\t\(.status)\t\(.conclusion)\t" + ([.steps[]?.name] | join(";"))' \
    2>/dev/null || true)

  amd64="" arm64="" publish="" trigger_src=""
  while IFS=$'\t' read -r jname jstatus jconc jsteps; do
    [ -z "$jname" ] && continue
    [ "$jstatus" != "completed" ] && { jconc="running"; ANY_RUNNING=1; }
    case "$jname" in
      *amd64*)   amd64="$jconc" ;;
      *arm64*)   arm64="$jconc" ;;
      publish*)  publish="$jconc" ;;
      env)
        [[ "$jsteps" =~ Triggered\ by:\ ([a-z]+) ]] && trigger_src="${BASH_REMATCH[1]}"
        ;;
    esac
  done <<< "$jobs"

  case "$event" in
    push)              trigger_src="push" ;;
    workflow_dispatch)  trigger_src="${trigger_src:-manual}" ;;
    *)                  trigger_src="${trigger_src:-$event}" ;;
  esac

  row_failed=0
  for c in "$amd64" "$arm64" "$publish"; do
    [ "$c" = "failure" ] && row_failed=1 && ANY_FAILED=1
  done

  if [ "$FAILED_ONLY" -eq 1 ] && [ "$row_failed" -eq 0 ]; then
    continue
  fi

  # Only fetch a last-known-good date when something on this row failed
  # -- one extra API call, but skipped entirely for healthy feedstocks.
  last_ok="never"
  if [ "$row_failed" -eq 1 ]; then
    last_ok=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.yml/runs" \
      --jq '.workflow_runs[] | select(.conclusion=="success") | .updated_at' \
      2>/dev/null | head -1 | cut -c1-10 || true)
    [ -z "$last_ok" ] && last_ok="never"
  fi

  [ "$ntags" = "0" ] && c_ntags="${YELLOW}" || c_ntags="${GREEN}"
  [ "$latest_tag" = "(none)" ] && c_tag="${YELLOW}" || c_tag="${RESET}"

  printf "%-30s  ${c_ntags}%-5s${RESET}  ${c_tag}%-14s${RESET}  " "$repo" "$ntags" "$latest_tag"
  cell "$amd64" "$last_ok"; printf " "
  cell "$arm64" "$last_ok"; printf " "
  cell "$publish" "$last_ok"; printf " "
  printf "%-19s  ${CYAN}%s${RESET}\n" "${trigger_src}@${ref}" "$branches"
  # Run URL on its own indented line -- opt-in (VERBOSE=1) since it's
  # rarely needed and doubles the line count of an already-long table.
  if [ "$VERBOSE" = "1" ]; then
    printf "%-53s${DIM}%s${RESET}\n" "" "$url"
  fi
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
