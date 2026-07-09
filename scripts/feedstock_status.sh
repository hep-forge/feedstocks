#!/usr/bin/env bash
# One status table per feedstock: published SIZE, tags, the latest CI
# run broken down by job (amd64 / arm64 / publish), what triggered it,
# and labels.
#
# A job cell shows the LATEST run's outcome: PASS/FAIL/skip/RUNNING.
#
# SIZE and the published-version counts in LABELS come from one batched
# anaconda.org fetch (scripts/channel_packages.py --sizes) up front --
# not a fetch per feedstock -- since it needs every package's file list
# to sum sizes.
#
# The LABELS column names, though, come from local remote-tracking refs
# (git branch -r), not a live GitHub query -- deliberately, to avoid a
# fetch per feedstock (56 network round-trips) on every invocation. If a
# branch was deleted upstream (e.g. via the GitHub API rather than a
# normal push/pull), your local clone won't know until pruned -- it'll
# keep showing the stale branch name forever. Run with --prune once
# after any upstream branch deletion/rename to clean the cache;
# otherwise skip it. "main" is always sorted first in this column, the
# rest alphabetically.
#
# NTAGS vs. the version counts in LABELS deliberately measure different
# things and often won't match: NTAGS is every git tag ever created,
# including ones superseded by a retag-to-rebuild (root has 8 tags but
# only 2 currently published, since 6 were retagged away); LABELS shows
# what's actually live on anaconda.org right now. NTAGS is kept because
# a big gap between them is itself a useful signal (a package retagged
# many times).
#
# The footer summary sums NTAGS/SIZE across every printed row and counts
# how many have a failing leg on their latest run vs. have never
# published anything (SIZE shows "-").
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

# Colorize a job conclusion into a fixed-width cell
cell() {
  local c="$1"
  case "$c" in
    success)   printf "${GREEN}%-9s${RESET}" "PASS" ;;
    failure)   printf "${RED}%-9s${RESET}" "FAIL" ;;
    skipped)   printf "${DIM}%-9s${RESET}" "skip" ;;
    cancelled) printf "${YELLOW}%-9s${RESET}" "CANCEL" ;;
    running)   printf "${YELLOW}%-9s${RESET}" "RUNNING" ;;
    "")        printf "${DIM}%-9s${RESET}" "-" ;;
    *)         printf "${YELLOW}%-9s${RESET}" "${c:0:9}" ;;
  esac
}

# One-shot fetch of total published size + per-label version counts for
# every package on the channel (~60 anaconda.org calls, done concurrently
# in Python -- a few seconds total, vs. one round-trip per feedstock row
# if done here in bash). Degrades to blank SIZE/label-counts if offline
# or the API is unreachable; the rest of the table still works.
declare -A SIZE_HUMAN
declare -A SIZE_BYTES
declare -A LABEL_COUNTS
while IFS=$'\t' read -r s_pkg s_bytes s_human s_labels; do
  [ -z "$s_pkg" ] && continue
  SIZE_HUMAN["$s_pkg"]="$s_human"
  SIZE_BYTES["$s_pkg"]="$s_bytes"
  LABEL_COUNTS["$s_pkg"]="$s_labels"
done < <(python3 scripts/channel_packages.py --sizes 2>/dev/null | grep -v '^#')

# Look up how many published versions a label has for the current $pkg
# (from LABEL_COUNTS, format "label:n,label:n,..."); "" if unknown.
label_version_count() {
  local label="$1"
  echo "${LABEL_COUNTS[$pkg]:-}" | tr ',' '\n' | awk -F: -v n="$label" '$1==n{print $2}'
}

human_size() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1073741824) printf "%.2fGB", b/1073741824;
    else if (b >= 1048576) printf "%.1fMB", b/1048576;
    else if (b >= 1024) printf "%.1fKB", b/1024;
    else printf "%dB", b;
  }'
}

printf "${BOLD}${CYAN}%-16s  %-9s  %-5s  %-14s  %-9s %-9s %-9s %-19s  %s${RESET}\n" \
  "PACKAGE" "SIZE" "NTAGS" "LATEST TAG" "AMD64" "ARM64" "PUBLISH" "TRIGGER@REF" "LABELS (published versions)"
printf "${DIM}"
printf '%0.s-' {1..140}
printf "${RESET}\n"

ANY_FAILED=0
ANY_RUNNING=0
TOTAL_ROWS=0
TOTAL_TAGS=0
TOTAL_BYTES=0
FAILED_ROWS=0
NOT_SUBMITTED_ROWS=0

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

  # Remote branches (each branch = one Anaconda label); strip origin/ prefix, exclude HEAD.
  # "main" always sorts first (the primary label), rest alphabetically.
  branches=$(git -C "$dir" branch -r --format='%(refname:short)' 2>/dev/null \
    | sed 's|^origin/||' | grep -v '^HEAD' | sort -u \
    | awk '{print ($0=="main"?0:1), $0}' | sort -k1,1n -k2,2 | cut -d' ' -f2-)
  [ -z "$branches" ] && branches="main"

  # Annotate each label/branch with how many versions anaconda.org has
  # published under it -- e.g. "main(2) old(5) legacy(0)" -- so a label
  # sitting on a pile of old versions (not just "main"), or a branch
  # with nothing published under it at all, stands out for cleanup.
  annotated=""
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    cnt=$(label_version_count "$b")
    annotated="$annotated ${b}(${cnt:-0})"
  done <<< "$branches"
  branches="${annotated# }"

  # Latest run + its per-job breakdown
  line=$(gh api "repos/$ORG/$repo/actions/workflows/autoupload.yml/runs?per_page=1" \
    --jq '.workflow_runs[0] | "\(.id)\t\(.status)\t\(.event)\t\(.head_branch)"' \
    2>/dev/null || true)

  TOTAL_ROWS=$((TOTAL_ROWS + 1))
  TOTAL_TAGS=$((TOTAL_TAGS + ntags))
  if [ -n "${SIZE_BYTES[$pkg]:-}" ]; then
    TOTAL_BYTES=$((TOTAL_BYTES + ${SIZE_BYTES[$pkg]}))
  else
    NOT_SUBMITTED_ROWS=$((NOT_SUBMITTED_ROWS + 1))
  fi

  if [ -z "$line" ] || [ "$line" = "null" ]; then
    [ "$FAILED_ONLY" -eq 1 ] && continue
    printf "%-16s  %-9s  ${c_ntags:-}%-5s${RESET}  %-14s  ${DIM}%s${RESET}\n" \
      "$pkg" "${SIZE_HUMAN[$pkg]:--}" "$ntags" "$latest_tag" "no runs"
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
  [ "$row_failed" -eq 1 ] && FAILED_ROWS=$((FAILED_ROWS + 1))

  if [ "$FAILED_ONLY" -eq 1 ] && [ "$row_failed" -eq 0 ]; then
    continue
  fi

  [ "$ntags" = "0" ] && c_ntags="${YELLOW}" || c_ntags="${GREEN}"
  [ "$latest_tag" = "(none)" ] && c_tag="${YELLOW}" || c_tag="${RESET}"

  printf "%-16s  %-9s  ${c_ntags}%-5s${RESET}  ${c_tag}%-14s${RESET}  " \
    "$pkg" "${SIZE_HUMAN[$pkg]:--}" "$ntags" "$latest_tag"
  cell "$amd64"; printf " "
  cell "$arm64"; printf " "
  cell "$publish"; printf " "
  printf "%-19s  ${CYAN}%s${RESET}\n" "${trigger_src}@${ref}" "$branches"
  # Run URL on its own indented line -- opt-in (VERBOSE=1) since it's
  # rarely needed and doubles the line count of an already-long table.
  if [ "$VERBOSE" = "1" ]; then
    printf "%-52s${DIM}%s${RESET}\n" "" "$url"
  fi
done

echo ""
printf "${BOLD}%s packages${RESET}, ${BOLD}%s${RESET} tags total, ${BOLD}%s${RESET} published on anaconda.org\n" \
  "$TOTAL_ROWS" "$TOTAL_TAGS" "$(human_size "$TOTAL_BYTES")"
printf "%s failing on latest run, %s not yet submitted to anaconda.org\n" \
  "$([ "$FAILED_ROWS" -gt 0 ] && printf "${RED}%s${RESET}" "$FAILED_ROWS" || printf "${GREEN}0${RESET}")" \
  "$([ "$NOT_SUBMITTED_ROWS" -gt 0 ] && printf "${YELLOW}%s${RESET}" "$NOT_SUBMITTED_ROWS" || printf "${GREEN}0${RESET}")"
echo ""
if [ "$ANY_FAILED" -eq 1 ]; then
  printf "${RED}Some legs FAILED on the latest run.${RESET}\n"
  exit 1
elif [ "$ANY_RUNNING" -eq 1 ]; then
  printf "${YELLOW}No failures so far, but some runs are still in progress.${RESET}\n"
else
  printf "${GREEN}All legs green.${RESET}\n"
fi
