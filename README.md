# hep-feedstocks

[![hep-bot version check](https://github.com/hep-forge/hep-feedstocks/actions/workflows/hep-bot-check.yml/badge.svg)](https://github.com/hep-forge/hep-feedstocks/actions/workflows/hep-bot-check.yml)

Meta-repository of conda feedstocks for High Energy Physics software, published to the **[hep-forge](https://anaconda.org/hep-forge)** Anaconda channel.

Packages are built for **Linux amd64**, **Linux arm64**, and (for feedstocks migrated to the unified CI workflow, see below) **macOS arm64**, and can be installed alongside [conda-forge](https://conda-forge.org).

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
│   │   │   └── autoupload.yml       # amd64 + arm64 + macos-arm64 matrix build + upload
│   │   │       # (older, unmigrated feedstocks instead have a separate
│   │   │       #  autoupload.amd64.yml / autoupload.arm64.yml pair — see
│   │   │       #  "Build workflow" below)
│   │   ├── conda-forge.yml          # conda-smithy config (hep-forge channel)
│   │   └── Makefile                 # Local dev shortcuts (same as root)
│   └── …
├── scripts/
│   ├── generate_readme.py   # Regenerate all feedstock READMEs → hep-forge
│   ├── rerender_all.sh      # Run generate_readme.py across all feedstocks
│   ├── add_macos_arm64.sh   # Migrate one feedstock to the amd64+arm64+macos-arm64 matrix workflow
│   ├── templates/autoupload.yml  # Canonical 3-way matrix workflow used by add_macos_arm64.sh
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
make status       # Table: feedstock | tags | branches (=labels) | last amd64/arm64/macOS build date
make status FEEDSTOCK=rivet-feedstock    # Status for one feedstock
make rerun FEEDSTOCK=fastjet-feedstock   # Trigger one feedstock rebuild at its latest tag (all arches in parallel, if migrated)
make add-macos FEEDSTOCK=fastjet-feedstock  # Migrate one feedstock to the amd64+arm64+macos-arm64 matrix workflow
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
2. Builds with `conda build recipe/` on amd64, arm64, and (once migrated) macos-arm64
3. Uploads `.conda` packages to `https://anaconda.org/hep-forge/` with `anaconda upload --label <branch>`

To trigger a build: push a git tag inside the feedstock submodule, or `make rerun FEEDSTOCK=<name>`.

### amd64 + arm64 + macos-arm64 matrix workflow

Feedstocks migrated to `scripts/templates/autoupload.yml` build all three architectures as
one GitHub Actions run with a 3-leg matrix (`build (amd64, ubuntu-24.04, linux)`,
`build (arm64, ubuntu-24.04-arm, linux)`, `build (macos-arm64, macos-14, macos)`) — they
run in parallel and show up as three branches in the same run graph, instead of three
separate workflow files/runs. A single `publish` job waits on all three legs and uploads
every `.conda` it collects in one pass.

Feedstocks not yet migrated still use the older `autoupload.amd64.yml` +
`autoupload.arm64.yml` pair (Linux only, two separate workflow runs).
`make rerun` / `scripts/rerun_tags.sh` and `make status` / `scripts/feedstock_status.sh`
both detect which scheme a feedstock is on and behave accordingly.

To migrate a feedstock:

```bash
make add-macos FEEDSTOCK=fastjet-feedstock   # writes autoupload.yml, drops the amd64/arm64 pair,
                                              # adds osx_arm64 to conda-forge.yml
cd feedstocks/fastjet-feedstock
git diff                                     # review
git add -A && git commit -m "ci: add macos-arm64" && git push
```

A real macOS build can surface package-specific issues conda-forge's Linux builds never hit
— e.g. `nproc` doesn't exist on macOS (`sysctl -n hw.ncpu` does), and
`conda_build_config.yaml` compiler pins gated with `# [linux]` need their `zip_keys` group
gated the same way or the variant solver errors out on osx. See the commit history of
[`feedstocks/cubature-feedstock`](https://github.com/hep-forge/cubature-feedstock) for a
worked example of both the CI migration and the recipe fixes it needed.

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

In the feedstock repo on GitHub: **Actions → Anaconda Build & Upload (AMD64) → Run workflow**.

The package will appear at `https://anaconda.org/hep-forge/mypackage` once the build succeeds.

## License

[LGPL-2.1](LICENSE)
