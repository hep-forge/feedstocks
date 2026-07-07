#!/usr/bin/env bash
# Regenerate README.md for every feedstock, pointed at hep-forge, and
# sync the CI workflow from scripts/templates/autoupload.yml (the
# workflow is part of the render: README badges and the workflow must
# agree on names/behavior).
# Usage: bash scripts/rerender_all.sh [org]
set -e
ORG="${1:-hep-forge}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/generate_readme.py"
TEMPLATE="$ROOT/scripts/templates/autoupload.yml"
COMMENT_TEMPLATE="$ROOT/scripts/templates/hep-bot-comment.yml"

cd "$ROOT"

for dir in feedstocks/*-feedstock; do
    [ -f "$dir/recipe/meta.yaml" ] || continue
    echo "=== $dir ==="
    if [ -d "$dir/.github/workflows" ]; then
        cp "$TEMPLATE" "$dir/.github/workflows/autoupload.yml"
        echo "Synced .github/workflows/autoupload.yml"
        cp "$COMMENT_TEMPLATE" "$dir/.github/workflows/hep-bot-comment.yml"
        echo "Synced .github/workflows/hep-bot-comment.yml"
    fi
    python3 "$SCRIPT" "$dir" "$ORG"
done
