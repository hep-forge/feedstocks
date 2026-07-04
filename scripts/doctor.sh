#!/usr/bin/env bash
# Deep dependency-consistency diagnostic for one feedstock -- catches
# the class of bug that only otherwise shows up as a cryptic conda
# solver error after burning a CI run: a hep-forge dependency that
# isn't published at all, a conda_build_config.yaml `root:` (or other)
# variant slot with no matching build on one architecture, or a tag
# that's fallen behind recipe fixes already on main.
#
# `make inspect` answers "what happened on the latest run"; this
# answers "would the NEXT run even solve, and why not" -- run it BEFORE
# retagging, not after watching another red run.
#
# Usage:
#   bash scripts/doctor.sh <package>
#   make doctor <package>
#
# Requirements: gh CLI authenticated as a hep-forge org member, python3+pyyaml

set -uo pipefail
trap 'exit 0' PIPE

ORG="hep-forge"
PKG="${1:-}"
[ -z "$PKG" ] && { echo "Usage: bash scripts/doctor.sh <package>"; exit 1; }
PKG="${PKG%-feedstock}"
REPO="$PKG-feedstock"
DIR="feedstocks/$REPO"

cd "$(dirname "$0")/.."
[ -d "$DIR" ] || { echo "No such feedstock: $DIR"; exit 1; }

if [ -t 1 ]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"
  YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

printf "${BOLD}${CYAN}== %s: dependency consistency ==${RESET}\n" "$PKG"
DIR="$DIR" PKG="$PKG" ORG="$ORG" python3 <<'PYEOF'
import json, os, re, urllib.request
from pathlib import Path

DIR = os.environ["DIR"]
PKG = os.environ["PKG"]
ORG = os.environ["ORG"]

def strip_jinja(text):
    text = re.sub(r"\{%.*?%\}", "", text, flags=re.DOTALL)
    text = re.sub(r"\{\{.*?\}\}", "JINJA", text)
    return text

def load_yaml(path):
    import yaml
    try:
        text = Path(path).read_text()
    except OSError:
        return {}
    try:
        return yaml.safe_load(strip_jinja(text)) or {}
    except yaml.YAMLError:
        return {}

meta = load_yaml(f"{DIR}/recipe/meta.yaml")
cbc = load_yaml(f"{DIR}/recipe/conda_build_config.yaml")

feedstock_pkgs = {p.name[:-len("-feedstock")] for p in Path("feedstocks").glob("*-feedstock")}

def vkey(v):
    return [int(p) if p.isdigit() else -1 for p in re.split(r"[._-]", v)]

def published(pkg):
    try:
        with urllib.request.urlopen(f"https://api.anaconda.org/package/{ORG}/{pkg}", timeout=15) as r:
            d = json.load(r)
    except Exception:
        return None
    by_ver = {}
    for f in d.get("files", []):
        by_ver.setdefault(f.get("version", ""), set()).add(f.get("attrs", {}).get("subdir"))
    return by_ver

reqs = set()
for section in ("host", "run", "build"):
    for item in (meta.get("requirements", {}) or {}).get(section, []) or []:
        name = re.split(r"[\s<>=!]", str(item).strip(), 1)[0].strip()
        if name in feedstock_pkgs and name != PKG:
            reqs.add(name)

if not reqs:
    print("  (no hep-forge package dependencies detected)")
for dep in sorted(reqs):
    by_ver = published(dep)
    if by_ver is None:
        print(f"  ERROR  {dep}: not reachable on {ORG} (API error)")
        continue
    if not by_ver:
        print(f"  ERROR  {dep}: published with zero files")
        continue
    latest = max(by_ver, key=vkey)
    archs = sorted(a for a in by_ver[latest] if a)
    mark = "OK  " if ("noarch" in archs or len(archs) >= 2) else "WARN"
    print(f"  {mark}   {dep:<20} latest={latest:<14} arch={archs}")

# Cross-check this recipe's OWN variant matrix (root:, or any other
# zip_keys-worthy key) against what's actually published per-arch --
# this is exactly the "root:6.36 has no aarch64 build" class of bug.
for key in ("root", "libtorch"):
    variants = cbc.get(key)
    if not variants:
        continue
    by_ver = published(key if key == "root" else "root-plus")  # libtorch itself isn't hep-forge-published
    print(f"  -- {key}: variant matrix (this recipe's conda_build_config.yaml) --")
    if key != "root":
        print("     (skipping arch cross-check -- not a hep-forge package)")
        continue
    for rv in variants:
        matches = sorted((v for v in (by_ver or {}) if v.startswith(str(rv))), key=vkey)
        if not matches:
            print(f"     MISSING  {key} {rv}.*  -- nothing published at all")
            continue
        for v in matches:
            archs = sorted(a for a in by_ver[v] if a)
            if len(archs) >= 2:
                print(f"     OK       {key} {rv} -> {v}: {archs}")
            else:
                missing = "linux-aarch64" if "linux-aarch64" not in archs else "linux-64"
                print(f"     WARN     {key} {rv} -> {v}: {archs}  (missing {missing}!)")
PYEOF

echo ""
printf "${BOLD}${CYAN}== %s: tag freshness ==${RESET}\n" "$PKG"
LATEST_TAG=$(git -C "$DIR" tag --sort=-v:refname 2>/dev/null | grep '^[0-9]' | head -1)
if [ -z "$LATEST_TAG" ]; then
  printf "  ${YELLOW}no numeric tags${RESET}\n"
else
  git -C "$DIR" fetch -q origin main 2>/dev/null
  TAG_SHA=$(git -C "$DIR" rev-parse "refs/tags/$LATEST_TAG" 2>/dev/null)
  MAIN_SHA=$(git -C "$DIR" rev-parse origin/main 2>/dev/null)
  if [ "$TAG_SHA" = "$MAIN_SHA" ]; then
    printf "  ${GREEN}OK${RESET}: tag %s == origin/main tip\n" "$LATEST_TAG"
  else
    AHEAD=$(git -C "$DIR" rev-list --count "$LATEST_TAG..origin/main" 2>/dev/null || echo "?")
    printf "  ${YELLOW}STALE${RESET}: tag %s is %s commit(s) behind origin/main\n" "$LATEST_TAG" "$AHEAD"
    printf "        ${DIM}make retag %s${RESET}\n" "$PKG"
  fi
fi

echo ""
bash scripts/inspect_feedstock.sh "$PKG"
