#!/usr/bin/env bash
# Deep-dive one feedstock: everything needed to answer "is this package
# healthy and in sync?" in a single command.
#
#   1. Versions published on anaconda.org (per architecture, with dates)
#   2. Git tags on GitHub, with a sync verdict: latest numeric tag vs
#      latest published (non-dev) version
#   3. The most recent workflow runs and the per-job (amd64 / arm64 /
#      publish) breakdown of the newest one
#   4. When something failed: the error lines from the failed job logs
#
# Usage:
#   bash scripts/inspect_feedstock.sh pythia
#   make inspect FEEDSTOCK=pythia
#
# Requirements: gh CLI authenticated as a hep-forge org member, python3

set -uo pipefail

ORG="hep-forge"
PKG="${1:-}"
[ -z "$PKG" ] && { echo "Usage: bash scripts/inspect_feedstock.sh <package>"; exit 1; }
PKG="${PKG%-feedstock}"
REPO="$PKG-feedstock"

cd "$(dirname "$0")/.."

if [ -t 1 ]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"
  YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

hr() { printf "${DIM}%0.s-" {1..78}; printf "${RESET}\n"; }

# ---------- 1. anaconda.org ------------------------------------------------
# the python block prints the version table on stdout; the very last
# line is "LATEST <version>" so the shell can capture it
printf "${BOLD}${CYAN}== anaconda.org/%s/%s — published versions ==${RESET}\n" "$ORG" "$PKG"
ANACONDA_OUT=$(ORG="$ORG" PKG="$PKG" python3 <<'PYEOF'
import json, os, re, urllib.request
from collections import defaultdict

def vkey(v):
    return [int(p) if p.isdigit() else -1 for p in re.split(r"[._-]", v)]

url = "https://api.anaconda.org/package/{}/{}".format(os.environ["ORG"], os.environ["PKG"])
try:
    with urllib.request.urlopen(url, timeout=20) as resp:
        d = json.load(resp)
except Exception:
    raise SystemExit
by_ver = defaultdict(lambda: {"subdirs": set(), "date": ""})
for f in d.get("files", []):
    v = f.get("version", "?")
    by_ver[v]["subdirs"].add(f.get("attrs", {}).get("subdir", "?"))
    by_ver[v]["date"] = max(by_ver[v]["date"], (f.get("upload_time") or "")[:10])
if not by_ver:
    raise SystemExit
releases = [v for v in by_ver if "dev" not in v] or list(by_ver)
latest = max(releases, key=vkey)
for v in sorted(by_ver, key=vkey, reverse=True)[:12]:
    info = by_ver[v]
    mark = " <- latest" if v == latest else ""
    print("  {:<18} {:<12} {}{}".format(v, info["date"], ", ".join(sorted(info["subdirs"])), mark))
print("LATEST " + latest)
PYEOF
)
if [ -z "$ANACONDA_OUT" ]; then
  echo "  (not on anaconda.org, or API unreachable)"
  LATEST_PUB=""
else
  printf "%s\n" "$ANACONDA_OUT" | grep -v "^LATEST "
  LATEST_PUB=$(printf "%s\n" "$ANACONDA_OUT" | awk '/^LATEST /{print $2}')
fi
hr

# ---------- 2. GitHub tags + sync verdict ----------------------------------
printf "${BOLD}${CYAN}== github.com/%s/%s — tags ==${RESET}\n" "$ORG" "$REPO"
TAGS=$(gh api "repos/$ORG/$REPO/tags?per_page=100" --jq '.[].name' 2>/dev/null || true)
if [ -z "$TAGS" ]; then
  echo "  (no tags)"
  LATEST_TAG=""
else
  echo "$TAGS" | head -12 | sed 's/^/  /'
  LATEST_TAG=$(echo "$TAGS" | grep '^[0-9]' | sort -V | tail -1)
  LATEST_TAG="${LATEST_TAG:-$(echo "$TAGS" | head -1)}"
fi

if [ -n "$LATEST_TAG" ] && [ -n "$LATEST_PUB" ]; then
  # strip leading v and unify separators for a fair comparison
  norm() { echo "${1#v}" | tr '_-' '..'; }
  if [ "$(norm "$LATEST_TAG")" = "$(norm "$LATEST_PUB")" ]; then
    printf "  ${GREEN}SYNCED${RESET}: latest tag %s == latest published %s\n" "$LATEST_TAG" "$LATEST_PUB"
  else
    printf "  ${YELLOW}OUT OF SYNC${RESET}: latest tag %s, latest published %s\n" "$LATEST_TAG" "$LATEST_PUB"
  fi
fi
hr

# ---------- 3. workflow runs ------------------------------------------------
printf "${BOLD}${CYAN}== latest workflow runs (autoupload.yml) ==${RESET}\n"
gh run list --repo "$ORG/$REPO" --workflow autoupload.yml --limit 5 \
  --json databaseId,status,conclusion,event,headBranch,createdAt \
  --template '{{range .}}  {{printf "%.0f" .databaseId}}  {{.conclusion}}{{"\t"}}{{.status}}{{"\t"}}{{.event}}@{{.headBranch}}{{"\t"}}{{timeago .createdAt}}{{"\n"}}{{end}}' \
  2>/dev/null || echo "  (no runs)"

RUN_ID=$(gh run list --repo "$ORG/$REPO" --workflow autoupload.yml --limit 1 \
  --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
if [ -n "$RUN_ID" ]; then
  printf "${BOLD}  jobs of run %s:${RESET}\n" "$RUN_ID"
  FAILED_RUN=0
  while IFS=$'\t' read -r jname jstatus jconc; do
    [ -z "$jname" ] && continue
    case "$jconc" in
      success) color=$GREEN ;;
      failure) color=$RED; FAILED_RUN=1 ;;
      *)       color=$YELLOW ;;
    esac
    printf "    %-45s ${color}%s${RESET}\n" "$jname" "${jconc:-$jstatus}"
  done < <(gh api "repos/$ORG/$REPO/actions/runs/$RUN_ID/jobs?per_page=30" \
    --jq '.jobs[] | [.name, .status, .conclusion] | @tsv' 2>/dev/null)
  echo "  https://github.com/$ORG/$REPO/actions/runs/$RUN_ID"
  hr

  # ---------- 4. failure details ---------------------------------------------
  if [ "$FAILED_RUN" -eq 1 ]; then
    printf "${BOLD}${RED}== error lines from failed jobs ==${RESET}\n"
    gh run view "$RUN_ID" --repo "$ORG/$REPO" --log-failed 2>/dev/null \
      | grep -aE "(CondaBuildUserError|BuildScriptException|ExplainedDependencyNeedsBuildingError|RuntimeError|ModuleNotFoundError|CMake Error|configure: error|Unsatisfiable dependencies|[Ee]rror:|##\[error\]|fatal:|FAILED)" \
      | grep -avE "error_upload_url|# too new for" \
      | sed -E 's/\x1b\[[0-9;]*m//g;
                s/^([^\t]*)\t[^\t]*\t[0-9T:.Z-]+ /[\1] /;
                s|/[^ ]*conda-bld/[^ ]*_h_env_placehold[^/]*/|\$PREFIX/|g;
                s|/[^ ]*conda-bld/([^/ ]+)/work/|\$SRC_DIR(\1)/|g' \
      | awk '!seen[$0]++' \
      | head -25
    echo ""
    printf "${DIM}full log: gh run view %s --repo %s/%s --log-failed | less${RESET}\n" "$RUN_ID" "$ORG" "$REPO"
  fi
fi
