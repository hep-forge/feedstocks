# hep-feedstocks

[![hep-bot version check](https://github.com/hep-forge/.github/actions/workflows/hep-bot-check.yml/badge.svg)](https://github.com/hep-forge/.github/actions/workflows/hep-bot-check.yml)

Hi there 👋 — this is the entry point for the **hep-forge** organization: a distribution
channel implementing many High Energy Physics scientific packages, with some
HEP-specific packaging requirements conda-forge doesn't cover.

Meta-repository of conda feedstocks for High Energy Physics software, published to the **[hep-forge](https://anaconda.org/hep-forge)** Anaconda channel.

Packages are built for **Linux amd64** and **Linux arm64** (which also covers Apple Silicon via Docker, see "Build workflow" below), and can be installed alongside [conda-forge](https://conda-forge.org). If you need macOS or Windows builds, `conda-forge` itself is the right place to look. Missing a self-hosted runner platform, or want to help run one? Start a discussion in this repo's Discussions tab.

## Install

Every package is listed at [anaconda.org/hep-forge](https://anaconda.org/hep-forge) — sort by
version to see what's pre-built, then install:

```bash
conda install -c hep-forge -c conda-forge <package>
```

To protect against conda accidentally pulling the conda-forge version of a package that also exists there, co-install `root-guard`:

```bash
conda install -c hep-forge -c conda-forge root root-guard rivet lhapdf pythia
```

New to conda? Install [miniconda or mamba](https://docs.anaconda.com/miniconda/install/#quick-command-line-install) first.

For a reproducible, shareable setup, describe the environment in `environment.yml`:

```yaml
# environment.yml
name: myhep
channels:
  - hep-forge
  - conda-forge
dependencies:
  - cernlib
  - root
  - lhapdf
```

```bash
conda env create -n myhep -f environment.yml
conda activate myhep
```

## Packages

The table below is generated — after a rebuild wave finishes (`make status`
shows no failures), refresh it with `make readme-status` and commit. "Latest tag"
is the feedstock's release tag; "Published" is what anaconda.org actually serves,
with per-architecture availability.

<!-- status:begin -->
_Last refreshed: 2026-07-18 (`python3 scripts/update_readme_status.py`)_

| Feedstock | Latest tag | Published | amd64 | arm64 |
|-----------|------------|-----------|-------|-------|
| [acts](https://github.com/hep-forge/acts-feedstock) | `46.8.1` | [`46.8.1`](https://anaconda.org/hep-forge/acts) | ✅ | ✅ |
| [afterburner](https://github.com/hep-forge/afterburner-feedstock) | `0.2.1` | [`0.2.1`](https://anaconda.org/hep-forge/afterburner) | ✅ | ✅ |
| [apfel](https://github.com/hep-forge/apfel-feedstock) | `3.1.1` | [`3.1.1`](https://anaconda.org/hep-forge/apfel) | ✅ | ✅ |
| [apfelgrid](https://github.com/hep-forge/apfelgrid-feedstock) | `1.0.1` | [`1.0.1`](https://anaconda.org/hep-forge/apfelgrid) | ✅ | ✅ |
| [apfelxx](https://github.com/hep-forge/apfelxx-feedstock) | `4.8.0` | [`4.8.0`](https://anaconda.org/hep-forge/apfelxx) | ✅ | ✅ |
| [applgrid](https://github.com/hep-forge/applgrid-feedstock) | `1.6.35` | [`1.6.35`](https://anaconda.org/hep-forge/applgrid) | ✅ | ✅ |
| [cernlib](https://github.com/hep-forge/cernlib-feedstock) | `2024.09.16.0-free` | [`2024.09.16.0.free` ⚠️](https://anaconda.org/hep-forge/cernlib) | ✅ | ✅ |
| [chaplin](https://github.com/hep-forge/chaplin-feedstock) | `1.2` | [`1.2`](https://anaconda.org/hep-forge/chaplin) | ✅ | ✅ |
| [collier](https://github.com/hep-forge/collier-feedstock) | `1.2.8` | [`1.2.8`](https://anaconda.org/hep-forge/collier) | ✅ | ✅ |
| [combiner](https://github.com/hep-forge/combiner-feedstock) | `0.1.1` | [`0.1.1`](https://anaconda.org/hep-forge/combiner) | ✅ | ✅ |
| [covfie](https://github.com/hep-forge/covfie-feedstock) | `0.15.6` | [`0.15.6`](https://anaconda.org/hep-forge/covfie) | ✅ | ✅ |
| [cuba](https://github.com/hep-forge/cuba-feedstock) | `4.2.2` | [`4.2.2`](https://anaconda.org/hep-forge/cuba) | ✅ | ✅ |
| [cubature](https://github.com/hep-forge/cubature-feedstock) | `1.0.4` | [`1.0.4`](https://anaconda.org/hep-forge/cubature) | ✅ | ✅ |
| [curlpp](https://github.com/hep-forge/curlpp-feedstock) | `0.8.1.1` | [`0.8.1.1`](https://anaconda.org/hep-forge/curlpp) | ✅ | ✅ |
| [cuttools](https://github.com/hep-forge/cuttools-feedstock) | `2.0` | [`2.0`](https://anaconda.org/hep-forge/cuttools) | ✅ | ✅ |
| [dd4hep](https://github.com/hep-forge/dd4hep-feedstock) | `1.37` | [`1.37`](https://anaconda.org/hep-forge/dd4hep) | ✅ | ✅ |
| [delphes](https://github.com/hep-forge/delphes-feedstock) | `3.5.0` | [`3.5.0`](https://anaconda.org/hep-forge/delphes) | ✅ | ✅ |
| [difftop](https://github.com/hep-forge/difftop-feedstock) | `1.0.0` | [`1.0.0`](https://anaconda.org/hep-forge/difftop) | ✅ | ✅ |
| [djangoh](https://github.com/hep-forge/djangoh-feedstock) | `4.6.21` | [`4.6.21`](https://anaconda.org/hep-forge/djangoh) | ✅ | ✅ |
| [dyturbo](https://github.com/hep-forge/dyturbo-feedstock) | `1.4.2` | [`1.4.2`](https://anaconda.org/hep-forge/dyturbo) | ✅ | ✅ |
| [edm4hep](https://github.com/hep-forge/edm4hep-feedstock) | `1.0.0` | [`1.0.0`](https://anaconda.org/hep-forge/edm4hep) | ✅ | ✅ |
| [eic-smear](https://github.com/hep-forge/eic-smear-feedstock) | `1.1.17` | [`1.1.17`](https://anaconda.org/hep-forge/eic-smear) | ✅ | ✅ |
| [eko](https://github.com/hep-forge/eko-feedstock) | `0.14.6` | [`0.14.6`](https://anaconda.org/hep-forge/eko) | ✅ | ✅ |
| [emela](https://github.com/hep-forge/emela-feedstock) | `1.0` | [`1.0`](https://anaconda.org/hep-forge/emela) | ✅ | ✅ |
| [epic](https://github.com/hep-forge/epic-feedstock) | `26.06.0` | [`26.06.0`](https://anaconda.org/hep-forge/epic) | ✅ | ✅ |
| [escalade](https://github.com/hep-forge/escalade-feedstock) | `v9.08.26` | [`v9.08.26`](https://anaconda.org/hep-forge/escalade) | ✅ | ✅ |
| [estarlight](https://github.com/hep-forge/estarlight-feedstock) | `1.2.0` | [`1.2.0`](https://anaconda.org/hep-forge/estarlight) | ✅ | ✅ |
| [fastjet-contrib](https://github.com/hep-forge/fastjet-contrib-feedstock) | `1.103` | [`1.103`](https://anaconda.org/hep-forge/fastjet-contrib) | ✅ | ✅ |
| [fastjet](https://github.com/hep-forge/fastjet-feedstock) | `3.5.1` | [`3.5.1`](https://anaconda.org/hep-forge/fastjet) | ✅ | ✅ |
| [fastnlo](https://github.com/hep-forge/fastnlo-feedstock) | `2.6.0` | [`2.6.0`](https://anaconda.org/hep-forge/fastnlo) | ✅ | ✅ |
| [framel](https://github.com/hep-forge/framel-feedstock) | `8.48.4` | [`8.48.4`](https://anaconda.org/hep-forge/framel) | ✅ | ✅ |
| [framel-root](https://github.com/hep-forge/framel-root-feedstock) | `1.0.0` | [`1.0.0`](https://anaconda.org/hep-forge/framel-root) | ✅ | ✅ |
| [g4hepem](https://github.com/hep-forge/g4hepem-feedstock) | `20251114` | [`20251114`](https://anaconda.org/hep-forge/g4hepem) | ✅ | ✅ |
| [geant](https://github.com/hep-forge/geant-feedstock) | `11.4.1` | [`11.4.1`](https://anaconda.org/hep-forge/geant) | ✅ | ✅ |
| [gosam](https://github.com/hep-forge/gosam-feedstock) | `3.0.3` | [`3.0.3`](https://anaconda.org/hep-forge/gosam) | ✅ | ✅ |
| [hathor](https://github.com/hep-forge/hathor-feedstock) | `2.0` | [`2.0`](https://anaconda.org/hep-forge/hathor) | ✅ | ✅ |
| [hell](https://github.com/hep-forge/hell-feedstock) | `3.1` | [`3.1`](https://anaconda.org/hep-forge/hell) | ✅ | ✅ |
| [hellx](https://github.com/hep-forge/hellx-feedstock) | `3.0` | [`3.0`](https://anaconda.org/hep-forge/hellx) | ✅ | ✅ |
| [hepmc](https://github.com/hep-forge/hepmc-feedstock) | `3.3.1` | [`3.3.1`](https://anaconda.org/hep-forge/hepmc) | ✅ | ✅ |
| [hepmc-merger](https://github.com/hep-forge/hepmc-merger-feedstock) | `2.2.0` | [`2.2.0`](https://anaconda.org/hep-forge/hepmc-merger) | ✅ | ✅ |
| [herwig7](https://github.com/hep-forge/herwig7-feedstock) | `7.3.0` | [`7.3.0`](https://anaconda.org/hep-forge/herwig7) | ✅ | ✅ |
| [hoppet](https://github.com/hep-forge/hoppet-feedstock) | `2.2.0` | [`2.2.0`](https://anaconda.org/hep-forge/hoppet) | ✅ | ✅ |
| [inih](https://github.com/hep-forge/inih-feedstock) | `r60` | [`r60`](https://anaconda.org/hep-forge/inih) | ✅ | ✅ |
| [iregi](https://github.com/hep-forge/iregi-feedstock) | `1.1.0` | [`1.1.0`](https://anaconda.org/hep-forge/iregi) | ✅ | ✅ |
| [jana](https://github.com/hep-forge/jana-feedstock) | `2026.02.00` | [`2026.02.00`](https://anaconda.org/hep-forge/jana) | ✅ | ✅ |
| [kfrlib](https://github.com/hep-forge/kfrlib-feedstock) | `7.0.1` | [`7.0.1`](https://anaconda.org/hep-forge/kfrlib) | ✅ | ✅ |
| [lhapdf](https://github.com/hep-forge/lhapdf-feedstock) | `6.5.6` | [`6.5.6`](https://anaconda.org/hep-forge/lhapdf) | ✅ | ✅ |
| [libdate-tz](https://github.com/hep-forge/libdate-tz-feedstock) | `3.0.3` | [`3.0.3`](https://anaconda.org/hep-forge/libdate-tz) | ✅ | ✅ |
| [looptools](https://github.com/hep-forge/looptools-feedstock) | `2.16` | [`2.16`](https://anaconda.org/hep-forge/looptools) | ✅ | ✅ |
| [mcfm](https://github.com/hep-forge/mcfm-feedstock) | `10.3` | [`10.3`](https://anaconda.org/hep-forge/mcfm) | ✅ | ❌ |
| [minio-cpp](https://github.com/hep-forge/minio-cpp-feedstock) | `0.3.0.1` | [`0.3.0.1`](https://anaconda.org/hep-forge/minio-cpp) | ✅ | ✅ |
| [mpfun90](https://github.com/hep-forge/mpfun90-feedstock) | `2024.12.06` | [`2024.12.06`](https://anaconda.org/hep-forge/mpfun90) | ✅ | ✅ |
| [ninja-hep-ph](https://github.com/hep-forge/ninja-hep-ph-feedstock) | `1.2.0` | [`1.2.0`](https://anaconda.org/hep-forge/ninja-hep-ph) | ✅ | ✅ |
| [nlojetxx](https://github.com/hep-forge/nlojetxx-feedstock) | `4.1.3` | [`4.1.3`](https://anaconda.org/hep-forge/nlojetxx) | ✅ | ✅ |
| [nnlojet](https://github.com/hep-forge/nnlojet-feedstock) | `1.0.0` | [`1.0.0`](https://anaconda.org/hep-forge/nnlojet) | ✅ | ✅ |
| [nnpdf](https://github.com/hep-forge/nnpdf-feedstock) | `4.0.9` | [`4.0.9`](https://anaconda.org/hep-forge/nnpdf) | ✅ | ✅ |
| [npsim](https://github.com/hep-forge/npsim-feedstock) | `1.6.1` | [`1.6.1`](https://anaconda.org/hep-forge/npsim) | ✅ | ✅ |
| [numdiff](https://github.com/hep-forge/numdiff-feedstock) | `5.9.0` | [`5.9.0`](https://anaconda.org/hep-forge/numdiff) | ✅ | ✅ |
| [oneloop](https://github.com/hep-forge/oneloop-feedstock) | `3.7.2` | [`3.7.2`](https://anaconda.org/hep-forge/oneloop) | ✅ | ✅ |
| [pepper](https://github.com/hep-forge/pepper-feedstock) | `1.12.0` | [`1.12.0`](https://anaconda.org/hep-forge/pepper) | ✅ | ✅ |
| [pineappl](https://github.com/hep-forge/pineappl-feedstock) | `0.8.6` | [`0.8.6`](https://anaconda.org/hep-forge/pineappl) | ✅ | ✅ |
| [ploughshare](https://github.com/hep-forge/ploughshare-feedstock) | `0.0.20` | [`0.0.20`](https://anaconda.org/hep-forge/ploughshare) | ✅ | ✅ |
| [podio](https://github.com/hep-forge/podio-feedstock) | `1.7.0` | [`1.7.0`](https://anaconda.org/hep-forge/podio) | ✅ | ✅ |
| [professor](https://github.com/hep-forge/professor-feedstock) | `2.4.2` | [`2.4.2`](https://anaconda.org/hep-forge/professor) | ✅ | ✅ |
| [pythia](https://github.com/hep-forge/pythia-feedstock) | `8.3.12` | [`8.3.12`](https://anaconda.org/hep-forge/pythia) | ✅ | ✅ |
| [qcdloop](https://github.com/hep-forge/qcdloop-feedstock) | `2.0.9` | [`2.0.9`](https://anaconda.org/hep-forge/qcdloop) | ✅ | ❌ |
| [qcdnum](https://github.com/hep-forge/qcdnum-feedstock) | `18.00.00` | [`18.00.00`](https://anaconda.org/hep-forge/qcdnum) | ✅ | ✅ |
| [rapgap](https://github.com/hep-forge/rapgap-feedstock) | `3.310` | [`3.310`](https://anaconda.org/hep-forge/rapgap) | ✅ | ✅ |
| [rivet](https://github.com/hep-forge/rivet-feedstock) | `4.1.0` | [`4.1.0`](https://anaconda.org/hep-forge/rivet) | ✅ | ✅ |
| [root](https://github.com/hep-forge/root-feedstock) | `6.38.04` | [`6.38.04`](https://anaconda.org/hep-forge/root) | ✅ | ✅ |
| [root-guard](https://github.com/hep-forge/root-guard-feedstock) | `1.0` | [`1` ⚠️](https://anaconda.org/hep-forge/root-guard) | ✅ | ✅ |
| [root-plus](https://github.com/hep-forge/root-plus-feedstock) | `1.0.0` | [`beta` ⚠️](https://anaconda.org/hep-forge/root-plus) | ✅ | ✅ |
| [sherpa](https://github.com/hep-forge/sherpa-feedstock) | `2.2.16` | [`2.2.16`](https://anaconda.org/hep-forge/sherpa) | ✅ | ✅ |
| [sz3](https://github.com/hep-forge/sz3-feedstock) | `3.3.1` | [`3.3.1`](https://anaconda.org/hep-forge/sz3) | ✅ | ✅ |
| [thepeg](https://github.com/hep-forge/thepeg-feedstock) | `2.3.0` | [`2.3.0`](https://anaconda.org/hep-forge/thepeg) | ✅ | ✅ |
| [xfitter-dev](https://github.com/hep-forge/xfitter-dev-feedstock) | `2.2.1` | [`2.2.1`](https://anaconda.org/hep-forge/xfitter-dev) | ✅ | ✅ |
| [xfitter](https://github.com/hep-forge/xfitter-feedstock) | `2.2.1` | [`2.2.1`](https://anaconda.org/hep-forge/xfitter) | ✅ | ✅ |
| [yadism](https://github.com/hep-forge/yadism-feedstock) | `0.12.5` | [`0.12.5`](https://anaconda.org/hep-forge/yadism) | ✅ | ✅ |
| [yoda](https://github.com/hep-forge/yoda-feedstock) | `2.1.0` | [`2.1.0`](https://anaconda.org/hep-forge/yoda) | ✅ | ✅ |

⚠️ = published version differs from the latest feedstock tag (build failed or still running).
<!-- status:end -->

## Repository structure

```
hep-feedstocks/
├── feedstocks/              # Git submodules — one per package
│   ├── fastjet-feedstock/
│   │   ├── recipe/
│   │   │   ├── meta.yaml            # Build recipe
│   │   │   └── conda_build_config.yaml
│   │   ├── .github/workflows/
│   │   │   └── autoupload.yml       # amd64 + arm64 + macos-arm64 matrix build + upload
│   │   │       # (older, unmigrated feedstocks instead have a separate
│   │   │       #  autoupload.amd64.yml / autoupload.arm64.yml pair — see
│   │   │       #  "Build workflow" below)
│   │   ├── conda-forge.yml          # conda-smithy config (hep-forge channel)
│   │   └── Makefile                 # Local dev shortcuts (same as root)
│   └── …
├── scripts/
│   ├── templates/autoupload.yml  # Canonical CI workflow (tag-only, amd64+arm64 matrix)
│   ├── generate_readme.py   # Regenerate a feedstock README → hep-forge badges + arch table
│   ├── rerender_all.sh      # Sync workflow template + README across all feedstocks
│   ├── render_all.sh        # Full conda-smithy rerender (then re-applies the two above)
│   ├── feedstock_status.sh  # Tags/branches + latest run per feedstock: amd64 | arm64 | publish columns
│   ├── retag_all.sh         # Move latest tags to branch tips + push (fires tag builds)
│   ├── rename_master_to_main.sh  # One-time branch consolidation (needs admin PAT)
│   ├── update_readme_status.py  # Refresh the status table in this README
│   └── hep_bot/
│       ├── sources.yaml     # Upstream version URLs for each package
│       ├── dag.yaml         # Dependency graph (rebuild order)
│       ├── check_versions.py  # Weekly version checker → opens PRs
│       └── bump_version.py    # Rewrites meta.yaml version + sha256
├── analyses/
│   ├── environment.yml      # Reference conda environment
│   ├── locks/               # conda-lock snapshots (reproducible envs)
│   ├── reference/           # Reference .yoda outputs for regression checks
│   └── run_analysis.sh      # Run a Rivet analysis + compare with reference
├── .github/workflows/
│   ├── hep-bot-check.yml    # Weekly upstream version check (cron Mon 06:00 UTC)
│   ├── hep-bot-rebuild.yml  # Manual DAG-ordered rebuild trigger
│   ├── render-sync.yml      # Daily: sync workflow+README into feedstocks, refresh status table
│   ├── channel-maintenance.yml  # Weekly: master->main label fix + channel-wide version trim
│   └── replay-analysis.yml  # Rivet analysis replay on self-hosted runner
├── examples/
│   └── helloworld-feedstock/ # Minimal working example to copy from
└── Makefile                  # Meta-repo + per-feedstock dev shortcuts
```

## Makefile

The same `Makefile` works at the meta-repo root and inside any individual feedstock (it auto-detects context).

Any target that takes a package name accepts it as a **bare word right after the
target** — `make inspect root` — which is exactly equivalent to the longer
`make inspect FEEDSTOCK=root`. Either form works everywhere below; the name is
always the bare package name (`root`), never the repo/directory name
(`root-feedstock`) — scripts add or strip that suffix themselves. The one
exception is a flag like `--failed`, which `make` itself intercepts as its own
command-line option, so that one still needs `ARGS="--failed"`.

### Meta-repo level

```bash
make forge        # Install conda-smithy, conda-verify, anaconda-client
make render       # Rerender all feedstocks (conda smithy rerender)
make render fastjet                      # Rerender one feedstock
make readme       # Regenerate all README.md files pointed at hep-forge
make list         # List all locally built .conda packages
make anaconda     # Upload all built packages to the hep-forge channel
make bot-check    # Dry-run upstream version check (hep-bot)
make status       # Table: feedstock | tags | branches (=labels) | latest run split by
                  # job (amd64 | arm64 | publish) -- failed legs show how long ago
                  # that job last passed
make status rivet                        # Status for one feedstock
make status ARGS="--failed"              # Only rows with a red leg
make status ARGS="--prune"               # Also prune stale local branch refs first
make ci-status    # LATEST workflow run per feedstock: PASS/FAIL/RUNNING + link.
                  # Exits non-zero if anything failed — bot/cron friendly.
make ci-status rivet                     # Same, one feedstock
make inspect pythia                      # Deep dive: published versions per arch, GitHub
                  # tags + sync verdict, latest runs, error log on failure
make retag fastjet                       # Move the latest tag to the branch tip + push
                  # -> fires the tag build (THE rebuild mechanism under tag-only CI)
make retag-all    # Same, every feedstock
make readme-status  # Refresh the README status table below from anaconda.org
make rerun fastjet                       # Rebuild one feedstock at its latest tag (recipe AS OF THE TAG)
make rerun-all    # Rebuild ALL feedstocks at their latest tags (recipe AS OF THE TAG;
                  # prefer retag-all when recipes changed since tagging)
make distribute   # Copy this Makefile into every feedstock
make debug fastjet                       # Debug one feedstock build
```

> `make status` shows the latest run's per-job outcome directly (including
> failures and how long ago each leg last passed). Use `make ci-status` for
> just the overall run conclusion, including in-progress runs.

### Per-feedstock level (after `make distribute` or `cd feedstocks/X && make`)

```bash
make forge        # Install tools
make render       # Rerender this feedstock
make list         # List locally built packages
make anaconda     # Upload this feedstock's packages
make debug        # Debug this feedstock's build
```

## Build workflow

**Builds run only on numeric version tags** (`[0-9]*`). The GitHub Actions workflow:

1. Detects the tag → derives `ANACONDA_PACKAGE`, `ANACONDA_VERSION`, `ANACONDA_LABEL`
2. Builds with `conda build recipe/` on linux-amd64 and linux-arm64
3. Uploads `.conda` packages to `https://anaconda.org/hep-forge/` with `anaconda upload --label <branch>` — the publish job is tag-gated, refuses any `*dev*` version, and uploads each architecture independently (one failed leg doesn't block the other)

Manual runs from the Actions UI are allowed **only at a tag ref** (pick the tag as the
run's ref). Dispatching on a branch is a no-op — the run is skipped, nothing builds,
nothing uploads. There is no branch/dev-build mode.

To trigger a rebuild: `make retag <name>` — it moves the feedstock's latest tag
to the default-branch tip and force-pushes; the tag push fires the build with the current
recipe. (Dispatching at an *old* tag fails with "No event triggers defined in `on`":
`workflow_dispatch` reads the workflow file at the dispatched ref, which predates the
trigger.) Watch progress per architecture with `make status` (`ARGS="--failed"` for
only the broken rows), or get the full picture for one package — published versions per
architecture, GitHub tags, and error details on failure — with `make inspect <name>`.

### amd64 + arm64 matrix workflow

Every feedstock uses `scripts/templates/autoupload.yml`: both architectures build as one
GitHub Actions run with a 2-leg matrix (`build (amd64, ubuntu-24.04, linux)`,
`build (arm64, ubuntu-24.04-arm, linux)`) — they run in parallel and show up as two
branches in the same run graph. A single `publish` job waits on both legs and uploads
every `.conda` it collects in one pass.

There is deliberately **no macOS leg**: Docker on Apple Silicon runs linux-arm64
containers natively (no emulation), so the linux-arm64 packages already cover Macs at
full speed. The recipes stay Darwin-compatible anyway (portable `nproc`, gnuconfig
`config.sub`/`config.guess` refresh, Clang/libc++ patches) since linux-arm64 exercises
most of the same paths; `scripts/add_macos_arm64.sh` / `scripts/remove_macos_arm64.sh`
can re-add or re-remove the macOS leg across all feedstocks if that call ever changes.

Recipe fixes only take effect on rebuilds that check out a ref containing them:
`make retag x` (or `make retag-all`) is the standard path — it rebuilds the
*current* recipe under the clean tag version. `make rerun-all` re-dispatches every
feedstock at its latest existing tag (recipe *as of the tag*).

### README generation

`conda smithy rerender` normally writes a conda-forge-flavored `README.md` into each
feedstock (badges and links pointing at conda-forge, where these packages don't exist).
Two mechanisms keep hep-forge READMEs in place:

1. every feedstock's `conda-forge.yml` sets `skip_render: [README.md]`, so rerenders
   don't touch the README at all;
2. `make render` / `make readme` regenerate it from `recipe/meta.yaml` via
   `scripts/generate_readme.py` (badges, install command, and links all point at
   hep-forge, plus a per-architecture publication table);
3. **all of this is automated**: the `render-sync.yml` workflow (daily cron, manual
   dispatch, or any push touching the template/generators) runs
   `scripts/render_sync.sh --commit`, which syncs `scripts/templates/autoupload.yml` and
   the README into every feedstock, pushes what changed, refreshes the status table in
   this README, and bumps the submodule pointers — no manual render step required.

### Channel hygiene: branches, labels, storage

**Branch policy: every feedstock's only long-lived branch is `main`** (plus the
deliberate version-line branches described in the next section). Anaconda labels are
derived from branch names, so a stray `master` branch publishes under a `master` label —
invisible to default installs, which only read `main`. Consolidate stragglers with:

```bash
GH_TOKEN=<admin-pat> bash scripts/rename_master_to_main.sh   # needs repo-admin rights
bash scripts/rename_master_to_main.sh --dry-run              # preview
```

`make status` reads branch names from your **local** clone's remote-tracking refs, not a
live GitHub query (avoids 56 network round-trips on every invocation) — after deleting or
renaming a branch upstream, your local clone won't know until pruned, and will keep
showing the stale name forever. Run `make status ARGS=--prune` once to clean the cache.

**Storage (anaconda.org free tier) is trimmed automatically.** After every release, the
publish job deletes that package's old versions; the `Anaconda Channel Maintenance`
workflow (Mondays, or manual with a dry-run toggle) sweeps the whole channel and also
migrates any lingering `master`-label files to `main`. What survives a trim:

- the newest **2** non-dev versions of the package;
- any version with a file carrying a label other than `main`/`master` — this protects
  the version-line labels (`legacy`, `eic`, `cern`, `old`, …) automatically;
- to protect a specific version forever, give it the **`keep` label**:
  `anaconda copy hep-forge/<pkg>/<version> --from-label main --to-label keep` or via the
  anaconda.org web UI. No `meta.yaml` change needed — old versions stay listed there.
  (`anaconda label` itself has no per-package/version scoping — it always acts on the
  whole org account — which is exactly why it's the right tool for the one-time
  `master`→`main` migration below but the wrong one for protecting a single version.)

Everything else is deleted, including any pre-policy `*.dev` uploads.

### Multiple concurrent version lines

Some upstream projects maintain two active major lines at once (e.g. PYTHIA
6.x and 8.x), or this repo needs to keep more than one build of something
around on purpose. The convention: **one branch per line, one branch = one
Anaconda label** (see `scripts/rerun_tags.sh`'s header comment) — same
package name on every branch, different `recipe/` content, published under
the branch name as the label.

`apfel`, `hathor`, and `mcfm`-feedstock already do this with a `legacy`
branch for their older API line; `pythia-feedstock` follows the same
pattern for PYTHIA 6 (frozen at 6.4.28 since 2013, alongside `main`'s
actively-updated 8.x). Install a specific line with
`conda install -c hep-forge pythia --channel-label legacy` (or whatever
label the branch publishes under).

Keeping a `legacy`-style branch minimal and current is on you — hep-bot's
version check has no concept of "also check this other branch," so a
frozen line like PYTHIA 6 needs no upkeep, but an *actively releasing*
second line would need its own manual bump process (or a
`scripts/hep_bot` extension neither exists yet).

### ROOT's rolling version window

ROOT is manually versioned (`dag.yaml`: `auto_update: false`), but ~14
downstream feedstocks (rivet, rapgap, xfitter, hepmc, yoda, …) build a
matrix against multiple concurrent ROOT versions via a `root:` variant
list in `recipe/conda_build_config.yaml`. To keep that list from growing
forever, it's capped at the newest 2 versions using a generic helper that
works for *any* variant key used this way, not just `root:`
(`scripts/hep_bot/variant_versions.py` — e.g. `escalade`/`root-plus`-feedstock
also zip `libtorch:` against `root:`):

```bash
make root-bump VERSION=6.40           # ROOT-specific alias: add 6.40, drop the oldest, keep 2
make root-trim                        # ROOT-specific alias: just cap existing lists, no new version

make variant-bump KEY=libtorch VERSION=2.9.0    # same thing for any other key
make variant-trim KEY=libtorch
```

If the target key is `zip_keys`-paired with another key (positional
pairing — `root[i]` always builds against `libtorch[i]`), the whole
group is trimmed together automatically so the pairing stays valid;
adding a *new* version to a zip-paired key needs an explicit value for
its partner(s): `make variant-bump KEY=root VERSION=6.40 PAIR="libtorch=2.8.0"`.

This commits and pushes each affected feedstock directly.

### Legacy compatibility: pinning the compiler and glibc floor

Every compiled feedstock should explicitly pin, in its own
`recipe/conda_build_config.yaml`:

```yaml
c_stdlib:
  - sysroot                  # [linux]
c_stdlib_version:
  - 2.17                     # [linux] -- oldest broadly-supported glibc baseline

c_compiler_version:
  - 14                       # (and cxx_compiler_version / fortran_compiler_version)
```

**Why:** conda-forge periodically bumps its own *global* default sysroot
and compiler versions. A feedstock that doesn't pin these explicitly
floats along with whatever conda-forge's current default happens to be
on the day it's built — so the same recipe can silently start requiring
a newer glibc/GCC than it did last month, with no commit in this repo
recording that the compatibility floor moved. That's what forces a
reactive full-DAG rebuild later (once someone notices packages have
drifted out of sync with each other, or a package fails on an older
host than it used to support) instead of a deliberate, one-line version
bump when *we* decide to move the floor.

Pinning is a promise, and a build can still break it independently of
the pin: `make check-glibc` downloads each package's latest published
build and flags any `.so` requiring a newer GLIBC symbol than the pin
promises. A build.sh that overwrites `CFLAGS`/`CXXFLAGS` instead of
appending to them, or that runs a project's stale bundled `./configure`
instead of regenerating it with conda's own autotools
(`autoreconf --install --force`), can let the build host's own (newer)
glibc headers leak in regardless of what the pin says — e.g. GCC's C23
`strtol`/`atoi` redirect pulls in a `GLIBC_2.38` symbol version if no
`-std=` is pinned, even when `c_stdlib_version: 2.17` is set correctly.
This was found and fixed in `lhapdf-feedstock` (2026-07-08); a repo-wide
`make check-glibc` audit the same day found ~20 further feedstocks with
the same class of leak, and ~40 with no explicit `c_compiler_version`
pin at all (including `root-feedstock`) — cleanup in progress.

**Full flexibility is preserved**: this is a plain per-feedstock YAML
value, not a repo-wide lock. Anything that genuinely needs a newer
baseline (a real C++20 feature, a dependency that dropped old-glibc
support) pins forward on its own, without dragging the rest of the tree
along — the same override mechanism `root`'s rolling version window
above already uses for its own variant matrix.

### Rebuild order (DAG)

Rebuild in tier order; publish each tier before starting the next:

```
Tier 1  fastjet  hepmc  lhapdf  yoda
Tier 2  fastjet-contrib
Tier 3  rivet  applgrid  fastnlo  hoppet  apfel  apfelxx
Tier 4  rapgap  xfitter  nnpdf  …
```

The full graph is in [`scripts/hep_bot/dag.yaml`](scripts/hep_bot/dag.yaml). Use `make bot-check` to see which packages are behind upstream before triggering rebuilds.

## hep-bot (automated version tracking)

Two GitHub Actions workflows live in this meta-repo:

| Workflow | Trigger | Action |
|---|---|---|
| `hep-bot version check` | Every Monday 06:00 UTC, or manual | Scrapes upstream release pages; for each outdated package, commits the bump directly to that feedstock's own repo, then opens a PR **on this meta-repo** to bump the submodule pointer to match |
| `hep-bot ordered rebuild` | Manual (`workflow_dispatch`) | Triggers feedstock builds in DAG order, tier by tier, waiting for each tier to finish before starting the next |
| `Render & README Sync` | Daily 05:00 UTC, manual, or template/generator changes | Syncs the CI workflow template + hep-forge README into every feedstock, pushes what changed, refreshes this README's status table, bumps submodule pointers |
| `Anaconda Channel Maintenance` | Mondays 05:30 UTC, or manual (dry-run default) | Migrates lingering `master`-label files to `main`, trims old package versions channel-wide (keep newest 2 + any `keep`/version-line label) |

### Required secret

Create a GitHub Personal Access Token (fine-grained, scoped to the `hep-forge` org or at least `feedstocks` + the individual `-feedstock` repos it needs to touch) with these permissions, then add it as a repo secret:

| Permission | Level | Why |
|---|---|---|
| Contents | Read and write | Push commits |
| Workflows | Read and write | Push commits that touch `.github/workflows/*.yml` |
| Actions | Read and write | Trigger `workflow_dispatch` runs |
| Secrets | Read and write | Only needed once, to set this very secret via `gh secret set` |
| Pull requests | Read and write | `hep-bot version check` opens PRs for outdated packages |
| Metadata | Read-only | Mandatory baseline for any fine-grained PAT |

```
Settings → Secrets and variables → Actions → New repository secret
Name:  HEP_BOT_TOKEN
```

If `hep-forge` is an organization, a fine-grained PAT's permissions may need **org owner approval** before they take effect — check the token's settings page for a pending-approval banner if workflows keep failing with 403s after you've set the permissions.

### Trigger manually

Via the GitHub UI:

```
Actions → hep-bot version check → Run workflow
Actions → hep-bot ordered rebuild → Run workflow → root_package: fastjet, dry_run: true
```

Or via `gh` CLI:

```bash
gh workflow run hep-bot-check.yml --repo hep-forge/.github

gh workflow run hep-bot-rebuild.yml --repo hep-forge/.github \
  -f root_package=fastjet -f dry_run=true

# watch it
gh run list --repo hep-forge/.github --limit 5
gh run view <run-id> --repo hep-forge/.github --log
```

Always set `dry_run: true` first on the rebuild workflow to preview the tier plan before triggering actual builds — it prints something like:

```
Rebuild plan for 'fastjet' (9 package(s), 5 tier(s)):
  Tier 1: fastjet
  Tier 2: applgrid, fastjet-contrib, fastnlo
  Tier 3: apfelgrid, rivet
  Tier 4: rapgap, xfitter
  Tier 5: xfitter-dev
```

**`hep-bot version check` has no safe dry-run** — every manual or scheduled run does the real work (commits + opens PRs) for every outdated package it finds; there's a `--dry-run` flag on the underlying script (`make bot-check` runs it locally), but the workflow itself always calls the real path. Don't trigger it on a whim.

### What a real run looks like

A version check found `hepmc` behind (`3.3.0` → `3.3.1`) and:

1. Ran `scripts/hep_bot/bump_version.py hepmc 3.3.1`, which rewrote `feedstocks/hepmc-feedstock/recipe/meta.yaml`'s `versions` dict with the new version + freshly-downloaded sha256.
2. Committed and pushed that directly to `hep-forge/hepmc-feedstock`'s default branch: `[hep-bot] bump to 3.3.1`.
3. Opened a PR **on this meta-repo** bumping the `feedstocks/hepmc-feedstock` submodule pointer to that new commit: `[hep-bot] hepmc: 3.3.0 → 3.3.1`.

Merging that meta-repo PR is what actually moves this repo's copy of "which hepmc commit we're pinned to" forward — the feedstock repo itself is already updated regardless of whether/when you merge.

### Add a new package to hep-bot

1. Add an entry to [`scripts/hep_bot/sources.yaml`](scripts/hep_bot/sources.yaml) with the upstream URL and version regex
2. Add an entry to [`scripts/hep_bot/dag.yaml`](scripts/hep_bot/dag.yaml) with its `depends_on` list
3. Set `auto_update: false` if the package should never be auto-bumped (e.g. ROOT)

### Known rough edges

- If a recipe's `meta.yaml` has more than one `source: url:` line (e.g. gated behind a `{% if version_major < 3 %}` jinja conditional, like hepmc's HepMC-v2 vs HepMC3-v3 archive naming), `bump_version.py` tries each candidate and uses whichever one actually resolves — it doesn't evaluate the jinja logic itself.
- If one package's PR creation fails (e.g. it was already bumped by a previous run), `check_versions.py` logs the error and moves on to the rest of the DAG instead of aborting the whole run; it exits non-zero at the end if anything failed, so check the run log for `ERROR` lines rather than assuming a red X means nothing happened.

## Self-hosted runners

Self-hosted runners let you use your own lab machines for builds instead of GitHub's cloud VMs.
Benefits: no 6-hour timeout, persistent conda package cache (much faster rebuilds), no billing for compute.

By default all workflows use GitHub-hosted runners (`ubuntu-24.04` / `ubuntu-24.04-arm`). You only need to switch `runs-on:` in the individual feedstock workflow if you want a specific build to run on your machine — everything else keeps using GitHub's VMs automatically.

### Step 1 — Get a runner registration token

**Option A — Org-level runner (recommended, one runner serves all feedstocks):**

Go to: **github.com/hep-forge → Settings → Actions → Runners → New self-hosted runner**

**Option B — Repo-level runner (simpler, one runner per feedstock repo):**

Go to: **github.com/hep-forge/\<feedstock\> → Settings → Actions → Runners → New self-hosted runner**

On that page, GitHub shows you:
- The download URL for the runner package
- A one-time registration token (valid 1 hour)
- Copy the exact `config.sh` line shown — it already contains your token

### Step 2 — Install the runner on the machine

Run this on your lab machine. Replace `<ARCH>`, `<URL>`, and `<TOKEN>` with the values from the GitHub page above.

**AMD64 machine:**

```bash
mkdir ~/actions-runner && cd ~/actions-runner
curl -o runner.tar.gz -L <URL_FROM_GITHUB>
tar xzf runner.tar.gz

./config.sh \
  --url https://github.com/hep-forge \
  --token <TOKEN_FROM_GITHUB> \
  --name hep-forge-amd64-lab \
  --labels hep-forge-amd64 \
  --unattended

sudo ./svc.sh install
sudo ./svc.sh start
```

**ARM64 machine** (same steps, different label):

```bash
mkdir ~/actions-runner && cd ~/actions-runner
curl -o runner.tar.gz -L <URL_FROM_GITHUB>
tar xzf runner.tar.gz

./config.sh \
  --url https://github.com/hep-forge \
  --token <TOKEN_FROM_GITHUB> \
  --name hep-forge-arm64-lab \
  --labels hep-forge-arm64 \
  --unattended

sudo ./svc.sh install
sudo ./svc.sh start
```

After `svc.sh start`, the runner appears as **Online** in the GitHub UI. The service restarts automatically on reboot.

### Step 3 — Pre-install conda (one-time, speeds up every build)

```bash
# On the AMD64 machine
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ~/miniconda3
~/miniconda3/bin/conda install -n base -c conda-forge -y \
  conda-build anaconda-client conda-smithy conda-package-handling
```

```bash
# On the ARM64 machine
wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
bash Miniforge3-Linux-aarch64.sh -b -p ~/miniconda3
~/miniconda3/bin/conda install -n base -c conda-forge -y \
  conda-build anaconda-client conda-smithy conda-package-handling
```

### Step 4 — Route a feedstock to your runner

The workflows use GitHub-hosted runners by default. To switch a specific feedstock to your
machine, edit the matrix `runs-on:` value for the relevant leg in its
`.github/workflows/autoupload.yml` (or, for a feedstock not yet migrated, the `runs-on:` line
in its `autoupload.amd64.yml` / `autoupload.arm64.yml`):

```yaml
# Before (GitHub-hosted):
- id: amd64
  runs-on: ubuntu-24.04

# After (your AMD64 lab machine):
- id: amd64
  runs-on: [self-hosted, linux, X64, hep-forge-amd64]
```

```yaml
# Before:
- id: arm64
  runs-on: ubuntu-24.04-arm

# After (your ARM64 lab machine):
- id: arm64
  runs-on: [self-hosted, linux, ARM64, hep-forge-arm64]
```

For ROOT specifically, always prefer the self-hosted ARM64 runner — ROOT's build takes 4–6 hours and GitHub's hosted ARM runners have a strict 6-hour timeout.

### Check runner status

```bash
# On the lab machine
cd ~/actions-runner
sudo ./svc.sh status
```

Or check online at: **github.com/hep-forge → Settings → Actions → Runners**

## Analysis replay

Reproduce a Rivet analysis from a locked conda environment and compare against a stored reference output:

```bash
# Create a lock file for the current environment
conda-lock lock \
  --file analyses/environment.yml \
  --platform linux-64 \
  --lockfile analyses/locks/rivet-3.1.11-env.lock.yml

# Run and compare locally
bash analyses/run_analysis.sh ATLAS_2012_I1189423 /path/to/events.hepmc rivet-3.1.11-env

# Or trigger on the self-hosted runner via GitHub Actions
Actions → analysis replay → Run workflow
```

Reference `.yoda` outputs are stored in `analyses/reference/`. The first run stores the reference; subsequent runs diff against it with `rivet-cmp-histo`.

## Adding a new feedstock

The template used below also exists as its own pair of repos if you'd rather start from
GitHub directly: [hep-forge/helloworld](https://github.com/hep-forge/helloworld) (the
software being packaged) and [hep-forge/helloworld-feedstock](https://github.com/hep-forge/helloworld-feedstock)
(the recipe that publishes it) — same content as `examples/helloworld-feedstock` below.

### Step 1 — Create the repository on GitHub

Go to [github.com/hep-forge](https://github.com/hep-forge) → **New repository**.

Name it `<pkg>-feedstock` (e.g. `mypackage-feedstock`). Leave it empty (no README, no license) and click **Create repository**.

### Step 2 — Copy the template locally

```bash
cp -r examples/helloworld-feedstock feedstocks/mypackage-feedstock
cd feedstocks/mypackage-feedstock
git init
git remote add origin git@github.com:hep-forge/mypackage-feedstock.git
```

Everything in the template is already configured for hep-forge: channels, org name, workflow trigger, dev-build guard, Makefile. You do not need to edit any of those files.

### Step 3 — Write the recipe

Edit `recipe/meta.yaml`. The key fields to fill in:

```yaml
{% set name = "mypackage" %}
{% set version = "1.2.3" %}

package:
  name: {{ name }}
  version: {{ version }}

source:
  url: https://example.com/mypackage-{{ version }}.tar.gz
  sha256: <sha256 of the tarball>

build:
  number: 0
  # Add this block if the package installs .so shared libraries:
  run_exports:
    - {{ pin_subpackage(name, max_pin="x.x.x") }}

requirements:
  build:
    - {{ compiler('cxx') }}   # include if the package compiles C/C++
  host:
    - <dependencies>
  run:
    - <dependencies>

about:
  home: https://example.com/mypackage
  summary: One-line description
  license: GPL-2.0

extra:
  recipe-maintainers:
    - meiyasan
```

If the package compiles C/C++ code, `recipe/conda_build_config.yaml` already contains the glibc 2.17 floor — no changes needed there either.

### Step 4 — Generate the README and push

```bash
cd ../..                                  # back to hep-feedstocks root
make readme                               # generates feedstocks/mypackage-feedstock/README.md
cd feedstocks/mypackage-feedstock
git add -A
git commit -m "initial recipe for mypackage 1.2.3"
git push -u origin main
```

### Step 5 — Register as a submodule in this meta-repo

```bash
cd ../..                                  # back to hep-feedstocks root
git submodule add git@github.com:hep-forge/mypackage-feedstock.git feedstocks/mypackage-feedstock
git add .gitmodules feedstocks/mypackage-feedstock
git commit -m "add mypackage-feedstock submodule"
git push origin main
```

### Step 6 — Add to hep-bot (optional)

Add an entry to [`scripts/hep_bot/sources.yaml`](scripts/hep_bot/sources.yaml) so the weekly version checker monitors it:

```yaml
mypackage:
  type: html_scrape
  url: "https://example.com/mypackage/downloads/"
  pattern: 'mypackage-(\d+\.\d+\.\d+)\.tar\.gz'
```

Add an entry to [`scripts/hep_bot/dag.yaml`](scripts/hep_bot/dag.yaml) with its dependencies:

```yaml
mypackage:
  depends_on: [fastjet, lhapdf]   # or [] if no HEP dependencies
```

### Step 7 — Trigger the first build

Push a version tag in the feedstock repo — builds only run on numeric tags:

```bash
cd feedstocks/mypackage-feedstock
git tag 1.2.3 && git push origin refs/tags/1.2.3
```

The package will appear at `https://anaconda.org/hep-forge/mypackage` once the build succeeds.

## License

[LGPL-2.1](LICENSE)
