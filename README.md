# hep-feedstocks

[![hep-bot version check](https://github.com/hep-forge/hep-feedstocks/actions/workflows/hep-bot-check.yml/badge.svg)](https://github.com/hep-forge/hep-feedstocks/actions/workflows/hep-bot-check.yml)

Meta-repository of conda feedstocks for High Energy Physics software, published to the **[hep-forge](https://anaconda.org/hep-forge)** Anaconda channel.

Packages are built for **Linux amd64** and **Linux arm64** and can be installed alongside [conda-forge](https://conda-forge.org).

## Install

```bash
conda install -c hep-forge -c conda-forge <package>
```

To protect against conda accidentally pulling the conda-forge version of a package that also exists there, co-install `root-guard`:

```bash
conda install -c hep-forge -c conda-forge root root-guard rivet lhapdf pythia
```

## Packages

| Package | Version | Description |
|---------|---------|-------------|
| [fastjet](https://fastjet.fr) | 3.5.1 | Jet finding in pp and e+e− collisions |
| [fastjet-contrib](https://fastjet.hepforge.org/contrib/) | 1.056 | Third-party FastJet extensions |
| [rivet](https://rivet.hepforge.org) | 3.1.11 / 4.x | MC analysis toolkit |
| [lhapdf](https://lhapdf.hepforge.org) | — | PDF sets and evaluation |
| [hepmc](https://hepmc.web.cern.ch/hepmc/) | — | HEP Monte Carlo event record |
| [yoda](https://yoda.hepforge.org) | — | Histogramming for MC validation |
| [pythia](https://pythia.org) | — | General-purpose MC event generator |
| [hoppet](https://hoppet.hepforge.org) | — | DGLAP PDF evolution |
| [applgrid](https://applgrid.hepforge.org) | — | Fast pQCD predictions |
| [root](https://root.cern) | 6.32–6.38 | CERN ROOT data analysis framework |
| [rapgap](https://rapgap.hepforge.org) | — | MC generator for ep DIS |
| [xfitter](https://xfitter.org) | — | Open-source PDF fitting framework |
| … | | 56 feedstocks total |

## Repository structure

```
hep-feedstocks/
├── feedstocks/              # Git submodules — one per package
│   ├── fastjet-feedstock/
│   │   ├── recipe/
│   │   │   ├── meta.yaml            # Build recipe
│   │   │   └── conda_build_config.yaml
│   │   ├── .github/workflows/
│   │   │   ├── autoupload.amd64.yml # AMD64 build + upload to hep-forge
│   │   │   └── autoupload.arm64.yml # ARM64 build + upload to hep-forge
│   │   ├── conda-forge.yml          # conda-smithy config (hep-forge channel)
│   │   └── Makefile                 # Local dev shortcuts (same as root)
│   └── …
├── scripts/
│   ├── generate_readme.py   # Regenerate all feedstock READMEs → hep-forge
│   ├── rerender_all.sh      # Run generate_readme.py across all feedstocks
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
│   └── replay-analysis.yml  # Rivet analysis replay on self-hosted runner
├── examples/
│   └── helloworld-feedstock/ # Minimal working example to copy from
└── Makefile                  # Meta-repo + per-feedstock dev shortcuts
```

## Makefile

The same `Makefile` works at the meta-repo root and inside any individual feedstock (it auto-detects context).

### Meta-repo level

```bash
make forge        # Install conda-smithy, conda-verify, anaconda-client
make render       # Rerender all feedstocks (conda smithy rerender)
make render FEEDSTOCK=fastjet-feedstock  # Rerender one feedstock
make readme       # Regenerate all README.md files pointed at hep-forge
make list         # List all locally built .conda packages
make anaconda     # Upload all built packages to the hep-forge channel
make bot-check    # Dry-run upstream version check (hep-bot)
make distribute   # Copy this Makefile into every feedstock
make debug FEEDSTOCK=fastjet-feedstock   # Debug one feedstock build
```

### Per-feedstock level (after `make distribute` or `cd feedstocks/X && make`)

```bash
make forge        # Install tools
make render       # Rerender this feedstock
make list         # List locally built packages
make anaconda     # Upload this feedstock's packages
make debug        # Debug this feedstock's build
```

## Build workflow

Packages are built and uploaded automatically on each tagged commit in the feedstock repo. The GitHub Actions workflow:

1. Detects the tag → derives `ANACONDA_PACKAGE`, `ANACONDA_VERSION`, `ANACONDA_LABEL`
2. Builds with `conda build recipe/` on both AMD64 (`ubuntu-24.04`) and ARM64 (`ubuntu-24.04-arm` or self-hosted)
3. Uploads `.conda` packages to `https://anaconda.org/hep-forge/` with `anaconda upload --label <branch>`

To trigger a build: push a git tag inside the feedstock submodule.

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
| `hep-bot version check` | Every Monday 06:00 UTC, or manual | Scrapes upstream release pages; opens a PR for each outdated package |
| `hep-bot ordered rebuild` | Manual (`workflow_dispatch`) | Triggers feedstock builds in DAG order starting from a given package |

### Required secret

Create a GitHub Personal Access Token with **Contents**, **Pull requests**, and **Actions** write access, then add it to this repo:

```
Settings → Secrets and variables → Actions → New repository secret
Name:  HEP_BOT_TOKEN
```

### Trigger manually (GitHub UI or IDE)

```
Actions → hep-bot version check → Run workflow
Actions → hep-bot ordered rebuild → Run workflow → root_package: fastjet
```

Set `dry_run: true` on the rebuild workflow to preview the DAG order without triggering actual builds.

### Add a new package to hep-bot

1. Add an entry to [`scripts/hep_bot/sources.yaml`](scripts/hep_bot/sources.yaml) with the upstream URL and version regex
2. Add an entry to [`scripts/hep_bot/dag.yaml`](scripts/hep_bot/dag.yaml) with its `depends_on` list
3. Set `auto_update: false` if the package should never be auto-bumped (e.g. ROOT)

## Self-hosted runners

ARM64 builds for heavy packages (especially ROOT) should run on self-hosted lab machines to avoid GitHub's 6-hour job timeout and benefit from a persistent package cache.

### Register a lab machine

```bash
# On the lab machine (repeat for each machine)
mkdir ~/actions-runner && cd ~/actions-runner
curl -o runner.tar.gz -L <DOWNLOAD_URL_FROM_GITHUB_UI>
tar xzf runner.tar.gz

./config.sh \
  --url https://github.com/hep-forge \
  --token <REGISTRATION_TOKEN_FROM_GITHUB_UI> \
  --labels hep-forge-arm64 \       # or hep-forge-amd64
  --name hep-forge-arm64-lab \
  --unattended

sudo ./svc.sh install && sudo ./svc.sh start
```

Get the download URL and token from:
**`github.com/hep-forge` → Settings → Actions → Runners → New self-hosted runner**

### Pre-install conda on the runner (one-time, speeds up every build)

```bash
# ARM64 machine
wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
bash Miniforge3-Linux-aarch64.sh -b -p ~/miniforge3
~/miniforge3/bin/conda install -n base -c conda-forge -y \
  conda-build anaconda-client conda-smithy conda-package-handling
```

To route a feedstock's ARM64 build to the lab runner instead of `ubuntu-24.04-arm`, change the `runs-on:` line in `.github/workflows/autoupload.arm64.yml`:

```yaml
runs-on: [self-hosted, linux, ARM64, hep-forge-arm64]
```

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

1. Copy `examples/helloworld-feedstock/` as a starting point
2. Write `recipe/meta.yaml` — include `build.run_exports` if the package installs shared libraries
3. Add `c_stdlib_version: 2.17` to `recipe/conda_build_config.yaml` if the package compiles C/C++ code
4. The `conda-forge.yml` and workflow files are already correct (copied from the template); update `github.user_or_org: hep-forge`
5. Add the feedstock as a git submodule: `git submodule add git@github.com:hep-forge/<pkg>-feedstock feedstocks/<pkg>-feedstock`
6. Add entries to `scripts/hep_bot/sources.yaml` and `scripts/hep_bot/dag.yaml`
7. Run `make readme` to generate the feedstock's README

## License

[LGPL-2.1](LICENSE)
