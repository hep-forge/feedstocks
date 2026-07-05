#!/usr/bin/env bash
# Dependency-consistency diagnostic -- catches the class of bug that
# only otherwise shows up as a cryptic conda solver error after burning
# a CI run: a hep-forge dependency that isn't published at all, a
# conda_build_config.yaml `root:` (or other) variant slot with no
# matching build on one architecture, or a tag that's fallen behind
# recipe fixes already on main.
#
# `make inspect` answers "what happened on the latest run"; this
# answers "would the NEXT run even solve, and why not" -- run it BEFORE
# retagging, not after watching another red run.
#
# Usage:
#   bash scripts/doctor.sh              # all feedstocks, one line each
#                                        # (only prints detail for ones with issues)
#   bash scripts/doctor.sh <package>    # one feedstock, full detail + `inspect`
#   make doctor                         # same, all feedstocks
#   make doctor <package>               # same, one feedstock
#   make doctor <package> N=100         # same, last 100 lines per failed job (default 20)
#
# Requirements: gh CLI authenticated as a hep-forge org member, python3+pyyaml

set -uo pipefail
trap 'exit 0' PIPE

ORG="hep-forge"
PKG="${1:-}"

cd "$(dirname "$0")/.."

if [ -t 1 ]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"
  YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

# Prints one finding line per problem found (deps + this recipe's own
# root:/libtorch: variant matrix, cross-checked per-arch); nothing at
# all if clean. Exits 1 if it found anything.
check_one() {
  local dir="$1" pkg="$2"
  DIR="$dir" PKG="$pkg" ORG="$ORG" python3 <<'PYEOF'
import json, os, re, sys
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
    import urllib.request
    try:
        with urllib.request.urlopen(f"https://api.anaconda.org/package/{ORG}/{pkg}", timeout=15) as r:
            d = json.load(r)
    except Exception:
        return None
    by_ver = {}
    for f in d.get("files", []):
        by_ver.setdefault(f.get("version", ""), set()).add(f.get("attrs", {}).get("subdir"))
    return by_ver

problems = []

reqs = set()
for section in ("host", "run", "build"):
    for item in (meta.get("requirements", {}) or {}).get(section, []) or []:
        name = re.split(r"[\s<>=!]", str(item).strip(), 1)[0].strip()
        if name in feedstock_pkgs and name != PKG:
            reqs.add(name)

dep_lines = []
for dep in sorted(reqs):
    by_ver = published(dep)
    if by_ver is None:
        problems.append(f"ERROR  {dep}: not reachable on {ORG} (API error)")
        continue
    if not by_ver:
        problems.append(f"ERROR  {dep}: published with zero files")
        continue
    latest = max(by_ver, key=vkey)
    archs = sorted(a for a in by_ver[latest] if a)
    ok = "noarch" in archs or len(archs) >= 2
    line = f"{dep:<20} latest={latest:<14} arch={archs}"
    dep_lines.append(("OK  " if ok else "WARN", line))
    if not ok:
        problems.append(f"WARN   {line}")

variant_lines = []
for key in ("root", "libtorch"):
    variants = cbc.get(key)
    if not variants:
        continue
    by_ver = published(key if key == "root" else "root-plus")
    if key != "root":
        continue
    for rv in variants:
        matches = sorted((v for v in (by_ver or {}) if v.startswith(str(rv))), key=vkey)
        if not matches:
            variant_lines.append(("MISSING", f"{key} {rv}.*  -- nothing published at all"))
            problems.append(f"MISSING  {key} {rv}.* -- nothing published at all")
            continue
        for v in matches:
            archs = sorted(a for a in by_ver[v] if a)
            if len(archs) >= 2:
                variant_lines.append(("OK", f"{key} {rv} -> {v}: {archs}"))
            else:
                missing = "linux-aarch64" if "linux-aarch64" not in archs else "linux-64"
                variant_lines.append(("WARN", f"{key} {rv} -> {v}: {archs}  (missing {missing}!)"))
                problems.append(f"WARN   {key} {rv} -> {v}: {archs} (missing {missing}!)")

QUIET = os.environ.get("DOCTOR_QUIET") == "1"
if QUIET:
    for p in problems:
        print(p)
else:
    if not reqs:
        print("  (no hep-forge package dependencies detected)")
    for mark, line in dep_lines:
        print(f"  {mark}   {line}")
    if variant_lines:
        for key in ("root", "libtorch"):
            keyed = [l for m, l in variant_lines if l.startswith(key + " ")]
            if not keyed:
                continue
            print(f"  -- {key}: variant matrix (this recipe's conda_build_config.yaml) --")
            for mark, line in variant_lines:
                if line.startswith(key + " "):
                    print(f"     {mark:<8} {line}")

sys.exit(1 if problems else 0)
PYEOF
}

tag_freshness() {
  local dir="$1"
  local latest_tag main_sha tag_sha
  latest_tag=$(git -C "$dir" tag --sort=-v:refname 2>/dev/null | grep '^[0-9]' | head -1)
  if [ -z "$latest_tag" ]; then
    echo "NOTAG"
    return
  fi
  git -C "$dir" fetch -q origin main 2>/dev/null
  tag_sha=$(git -C "$dir" rev-parse "refs/tags/$latest_tag" 2>/dev/null)
  main_sha=$(git -C "$dir" rev-parse origin/main 2>/dev/null)
  if [ "$tag_sha" = "$main_sha" ]; then
    echo "OK $latest_tag"
  else
    local ahead
    ahead=$(git -C "$dir" rev-list --count "$latest_tag..origin/main" 2>/dev/null || echo "?")
    echo "STALE $latest_tag $ahead"
  fi
}

if [ -z "$PKG" ]; then
  # ---------- all feedstocks: condensed, one line each ----------------------
  printf "${BOLD}${CYAN}== doctor: all feedstocks ==${RESET}\n"
  ANY_ISSUE=0
  for dir in feedstocks/*-feedstock; do
    [ -e "$dir/.git" ] || continue
    pkg=$(basename "$dir" | sed 's/-feedstock$//')

    ISSUES=$(DOCTOR_QUIET=1 check_one "$dir" "$pkg")
    DEP_STATUS=$?
    TAG_OUT=$(tag_freshness "$dir")
    TAG_STATE=$(echo "$TAG_OUT" | awk '{print $1}')

    if [ "$DEP_STATUS" -ne 0 ] || [ "$TAG_STATE" = "STALE" ]; then
      ANY_ISSUE=1
      printf "${RED}%-24s${RESET} issues found\n" "$pkg"
      [ -n "$ISSUES" ] && echo "$ISSUES" | sed 's/^/    /'
      if [ "$TAG_STATE" = "STALE" ]; then
        tag=$(echo "$TAG_OUT" | awk '{print $2}')
        ahead=$(echo "$TAG_OUT" | awk '{print $3}')
        printf "    ${YELLOW}STALE${RESET}  tag %s is %s commit(s) behind main -- make retag %s\n" "$tag" "$ahead" "$pkg"
      fi
    else
      printf "${GREEN}%-24s${RESET} OK\n" "$pkg"
    fi
  done
  echo ""
  if [ "$ANY_ISSUE" -eq 1 ]; then
    printf "${RED}Some feedstocks have dependency or tag issues.${RESET} Run 'make doctor <name>' for detail.\n"
    exit 1
  else
    printf "${GREEN}All feedstocks look consistent.${RESET}\n"
  fi
  exit 0
fi

# ---------- single feedstock: full detail ------------------------------------
PKG="${PKG%-feedstock}"
REPO="$PKG-feedstock"
DIR="feedstocks/$REPO"
[ -d "$DIR" ] || { echo "No such feedstock: $DIR"; exit 1; }

printf "${BOLD}${CYAN}== %s: dependency consistency ==${RESET}\n" "$PKG"
check_one "$DIR" "$PKG"

echo ""
printf "${BOLD}${CYAN}== %s: tag freshness ==${RESET}\n" "$PKG"
TAG_OUT=$(tag_freshness "$DIR")
case "$TAG_OUT" in
  NOTAG) printf "  ${YELLOW}no numeric tags${RESET}\n" ;;
  OK\ *) printf "  ${GREEN}OK${RESET}: tag %s == origin/main tip\n" "$(echo "$TAG_OUT" | awk '{print $2}')" ;;
  STALE\ *)
    tag=$(echo "$TAG_OUT" | awk '{print $2}')
    ahead=$(echo "$TAG_OUT" | awk '{print $3}')
    printf "  ${YELLOW}STALE${RESET}: tag %s is %s commit(s) behind origin/main\n" "$tag" "$ahead"
    printf "        ${DIM}make retag %s${RESET}\n" "$PKG"
    ;;
esac

echo ""
bash scripts/inspect_feedstock.sh "$PKG"
