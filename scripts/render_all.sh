#!/usr/bin/env bash
# Rerender feedstocks with conda-smithy, one line of live status per
# feedstock, full output captured to a per-feedstock log so failures can be
# inspected and replayed without re-running everything.
#
# Usage:
#   bash scripts/render_all.sh                # all feedstocks
#   bash scripts/render_all.sh fastjet         # one feedstock
#   bash scripts/render_all.sh --retry         # only feedstocks that failed last run
#
# Output:
#   .render-logs/<feedstock>.log   full conda smithy rerender output
#   .render-logs/FAILED            names of feedstocks that failed this run
#                                   (input for the next --retry)
#
# Requires: conda-smithy installed (make forge)

set -uo pipefail

cd "$(dirname "$0")/.."

LOG_DIR=".render-logs"
FAILED_FILE="$LOG_DIR/FAILED"
mkdir -p "$LOG_DIR"

RETRY=0
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --retry) RETRY=1 ;;
    --*) echo "Unknown flag: $arg"; exit 1 ;;
    *)   FILTER="$arg" ;;
  esac
done

if [ "$RETRY" -eq 1 ]; then
  [ -s "$FAILED_FILE" ] || { echo "No failures recorded in $FAILED_FILE — nothing to retry."; exit 0; }
  mapfile -t TARGETS < "$FAILED_FILE"
  echo "Retrying ${#TARGETS[@]} feedstock(s) from $FAILED_FILE"
elif [ -n "$FILTER" ]; then
  pkg="${FILTER%-feedstock}"
  TARGETS=("${pkg}-feedstock")
else
  TARGETS=()
  for dir in feedstocks/*-feedstock; do
    TARGETS+=("$(basename "$dir")")
  done
fi

TOTAL=${#TARGETS[@]}
OK=0
FAIL=0
: > "$FAILED_FILE.new"

for i in "${!TARGETS[@]}"; do
  repo="${TARGETS[$i]}"
  dir="feedstocks/$repo"
  n=$((i + 1))

  if [ ! -d "$dir" ]; then
    printf "[%2d/%2d] %-35s SKIP (no such feedstock)\n" "$n" "$TOTAL" "$repo"
    continue
  fi

  log="$LOG_DIR/$repo.log"
  (
    cd "$dir" && \
      conda smithy rerender --no-check-uptodate && \
      echo "!Makefile" >> .gitignore && \
      echo "!.github"  >> .gitignore && \
      { git add .gitignore 2>/dev/null || true; } && \
      find . -maxdepth 3 -name conda-build.yml -delete && \
      rm -rf .scripts
  ) > "$log" 2>&1
  status=$?

  # conda-smithy writes a conda-forge-flavored README (conda-forge badges,
  # channels, links); replace it with the hep-forge one. skip_render in
  # conda-forge.yml stops smithy from writing it at all, but regenerate
  # unconditionally so pre-skip_render feedstocks converge too.
  if [ "$status" -eq 0 ]; then
    python3 scripts/generate_readme.py "$dir" hep-forge >> "$log" 2>&1 || status=$?
  fi

  if [ "$status" -eq 0 ]; then
    OK=$((OK + 1))
    printf "[%2d/%2d] %-35s OK\n" "$n" "$TOTAL" "$repo"
  else
    FAIL=$((FAIL + 1))
    echo "$repo" >> "$FAILED_FILE.new"
    last_line=$(tail -1 "$log")
    printf "[%2d/%2d] %-35s FAIL  %s\n" "$n" "$TOTAL" "$repo" "($log)"
    printf "        └─ %s\n" "$last_line"
  fi
done

mv "$FAILED_FILE.new" "$FAILED_FILE"

echo ""
echo "Rendered: $OK OK, $FAIL failed (of $TOTAL)"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed feedstocks logged in $FAILED_FILE — inspect with:"
  echo "  cat $LOG_DIR/<feedstock>.log"
  echo "Fix and replay just the failures with:"
  echo "  bash scripts/render_all.sh --retry"
  exit 1
fi
