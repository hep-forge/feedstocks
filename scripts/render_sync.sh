#!/usr/bin/env bash
# End-to-end render automation, safe to run repeatedly (idempotent):
#
#   1. put every feedstock submodule on its remote default branch tip
#      (CI checks out pinned SHAs = detached HEAD, which can't be pushed)
#   2. sync scripts/templates/autoupload.yml + regenerate the hep-forge
#      README into every feedstock (scripts/rerender_all.sh)
#   3. commit + push feedstocks whose workflow/README changed
#   4. refresh the status table in the meta-repo README.md
#   5. --commit: also commit README.md + submodule pointer bumps here
#
# Run by .github/workflows/render-sync.yml (cron + dispatch + template
# changes); works identically from a laptop:
#
#   bash scripts/render_sync.sh            # steps 1-4
#   bash scripts/render_sync.sh --commit   # + meta-repo commit/push
#
# Requirements: git push rights on the feedstock repos, python3 + pyyaml

set -uo pipefail
cd "$(dirname "$0")/.."

COMMIT=0
[ "${1:-}" = "--commit" ] && COMMIT=1

# -- 1. every submodule on its default branch tip --------------------------
for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue
  def=$(git -C "$dir" ls-remote --symref origin HEAD 2>/dev/null \
    | awk '/^ref:/{sub("refs/heads/","",$2); print $2}')
  def="${def:-main}"
  git -C "$dir" fetch -q origin "$def" 2>/dev/null || { echo "SKIP $dir (fetch failed)"; continue; }
  git -C "$dir" checkout -q -B "$def" "origin/$def" 2>/dev/null \
    || { echo "SKIP $dir (checkout failed — dirty tree?)"; continue; }
done

# -- 2. render: workflow template + hep-forge READMEs ----------------------
bash scripts/rerender_all.sh hep-forge | grep -v "^Synced\|^Updated" || true

# -- 3. push what changed ---------------------------------------------------
PUSHED=0
for dir in feedstocks/*-feedstock; do
  [ -e "$dir/.git" ] || continue
  git -C "$dir" status --porcelain --ignored=matching -- .github/workflows/autoupload.yml \
    .github/workflows/hep-bot-comment.yml README.md \
    | grep -q . || continue
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
  [ "$branch" = "HEAD" ] && { echo "SKIP $dir (detached HEAD)"; continue; }
  # -f: hep-bot-comment.yml is a brand-new file and conda-smithy's generated
  # .gitignore (`*` with only `!.github`, not `!/.github/workflows/**`) blocks
  # it from ever being staged otherwise -- autoupload.yml/README.md are
  # already tracked from initial scaffolding so gitignore doesn't affect them.
  git -C "$dir" add -f .github/workflows/autoupload.yml .github/workflows/hep-bot-comment.yml README.md
  git -C "$dir" commit -qm "render: sync CI workflow + hep-forge README [render-sync]" \
    || continue
  if git -C "$dir" push -q; then
    echo "PUSHED $dir"
    PUSHED=$((PUSHED+1))
  else
    echo "PUSH-FAIL $dir"
  fi
done
echo "Feedstocks pushed: $PUSHED"

# -- 4. meta-repo README status table ---------------------------------------
python3 scripts/update_readme_status.py

# -- 5. meta-repo commit -----------------------------------------------------
if [ "$COMMIT" -eq 1 ]; then
  git add README.md feedstocks
  if git diff --cached --quiet; then
    echo "Meta-repo: nothing to commit"
  else
    git commit -qm "render-sync: refresh README status table + submodule pointers"
    git push -q && echo "Meta-repo: pushed"
  fi
fi
