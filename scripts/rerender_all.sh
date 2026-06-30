#!/usr/bin/env bash
# Regenerate README.md for every feedstock, pointed at hep-forge.
# Usage: bash scripts/rerender_all.sh [org]
set -e
ORG="${1:-hep-forge}"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/generate_readme.py"

for dir in feedstocks/*-feedstock; do
    [ -f "$dir/recipe/meta.yaml" ] || continue
    echo "=== $dir ==="
    python3 "$SCRIPT" "$dir" "$ORG"
done
