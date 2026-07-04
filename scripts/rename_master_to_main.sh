#!/usr/bin/env bash
# Consolidate every feedstock onto a single `main` branch:
#
#   1. fast-forward `main` to `master` (all master-default repos have a
#      stale main; dyturbo's lone extra main commit is superseded CI
#      plumbing and gets merged over)
#   2. switch the repo default branch to `main`
#   3. delete `master`
#   4. point the local submodule clone at origin/main
#
# REQUIRES A TOKEN WITH REPO ADMINISTRATION (write) on the feedstock
# repos -- changing the default branch is an admin operation. The
# regular hep-bot contents token gets 403 on step 2. Run e.g.:
#
#   GH_TOKEN=<admin-pat> bash scripts/rename_master_to_main.sh
#   bash scripts/rename_master_to_main.sh --dry-run
#
# Anaconda labels are branch-derived: after this migration all uploads
# land under the `main` label. Clean lingering `master` labels on
# anaconda.org separately (see README "Channel hygiene").

set -uo pipefail

ORG="hep-forge"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(dirname "$0")/.."

for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue
  repo=$(basename "$dir")
  r="$ORG/$repo"

  default=$(gh api "repos/$r" --jq .default_branch 2>/dev/null)
  [ "$default" = "master" ] || continue

  master_sha=$(gh api "repos/$r/git/ref/heads/master" --jq .object.sha 2>/dev/null)
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $repo: main <- master ($master_sha), default=main, delete master"
    continue
  fi

  # main may not exist yet, may be behind (fast-forward), or may have
  # diverged (merge master in -- master is authoritative)
  if ! gh api "repos/$r/git/ref/heads/main" >/dev/null 2>&1; then
    gh api -X POST "repos/$r/git/refs" -f ref="refs/heads/main" -f sha="$master_sha" >/dev/null \
      || { echo "$repo: FAILED creating main"; continue; }
  elif ! gh api -X PATCH "repos/$r/git/refs/heads/main" -f sha="$master_sha" >/dev/null 2>&1; then
    gh api -X POST "repos/$r/merges" -f base=main -f head=master \
      -f commit_message="merge master into main (branch consolidation)" >/dev/null \
      || { echo "$repo: FAILED updating main (diverged, merge failed)"; continue; }
  fi

  gh api -X PATCH "repos/$r" -f default_branch=main >/dev/null \
    || { echo "$repo: FAILED switching default branch (needs admin token)"; continue; }

  gh api -X DELETE "repos/$r/git/refs/heads/master" >/dev/null \
    || { echo "$repo: WARNING: default switched but master not deleted"; continue; }

  git -C "$dir" fetch -q origin
  git -C "$dir" checkout -q -B main origin/main 2>/dev/null
  git -C "$dir" remote set-head origin -a >/dev/null 2>&1

  echo "$repo: OK (main is default, master deleted)"
done
