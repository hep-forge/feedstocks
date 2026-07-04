# hep-feedstocks / hep-forge feedstock Makefile
#
# Self-detecting: works at the meta-repo root AND when copied into a single feedstock.
#   - Root level  (feedstocks/ dir present):  targets operate on ALL feedstocks
#   - Feedstock   (recipe/ dir present):       targets operate on THIS feedstock
#
# Any target below that takes a package name accepts it two ways —
# `make inspect root` and `make inspect FEEDSTOCK=root` are identical.
# The name is always the bare package name, never the "<name>-feedstock"
# repo/directory name (scripts strip or add that suffix themselves).
#
# Meta-repo usage:
#   make forge          Install conda-smithy + tools
#   make render [<name>]     Rerender all feedstocks, or just one
#                       one PASS/FAIL line per feedstock; full logs in .render-logs/
#   make render-retry   Re-run only the feedstocks that failed the last render
#   make readme         Regenerate all README.md files (hep-forge badges/links)
#   make list           List all built .conda packages across feedstocks
#   make anaconda       Upload all built packages to hep-forge channel
#   make bot-check      Dry-run upstream version check (hep-bot)
#   make distribute     Copy this Makefile into every feedstock
#   make debug <name>   Debug one feedstock build
#   make status [<name>]     Tags/branches + last AMD64/ARM64 build dates
#   make ci-status [<name>]  Latest workflow run per feedstock (PASS/FAIL/RUNNING + link)
#   make status-arch [<name>]  Latest run per feedstock split by job: amd64 | arm64 | publish
#   make status-arch ARGS=--failed  Same, only rows with a red leg
#                       (must be ARGS=..., not a bare --failed: make itself
#                       intercepts any --flag-looking word on its command line)
#   make retag <name>   Move latest tag to branch tip + push -> fires the tag build
#   make retag-all       Same for every feedstock (the rebuild mechanism under tag-only CI)
#   make readme-status   Refresh the feedstock status table in README.md from anaconda.org
#   make inspect <name>  Deep-dive one package: published versions per arch,
#                        GitHub tags + sync verdict, latest runs, error log on failure
#   make rerun <name>    Rebuild one feedstock at its latest tag (real release)
#   make rerun-all       Rebuild ALL feedstocks at their latest tags (no branch/dev builds)
#   make add-macos <name>  Migrate one feedstock's CI to the amd64+arm64+macos-arm64 matrix workflow
#   make add-macos-all   Migrate every feedstock not yet on the unified workflow
#   make variant-bump KEY=<name> VERSION=<value>  Roll a new version of any variant key out to consumers, trim to newest 2
#   make variant-trim KEY=<name>  Cap consumers' <name>: lists at the newest 2, no new version
#   make root-bump VERSION=<x.y>  Alias for variant-bump KEY=root
#   make root-trim       Alias for variant-trim KEY=root
#
# Per-feedstock usage (after 'make distribute' or cp):
#   make forge          Install conda-smithy + tools
#   make render         Rerender this feedstock
#   make list           List built packages from this feedstock
#   make anaconda       Upload this feedstock's packages
#   make debug          Debug this feedstock build

IS_META     := $(shell [ -d feedstocks ] && echo 1 || echo 0)
FEEDSTOCKS  := $(wildcard feedstocks/*-feedstock)
ANACONDA_TOKEN := $(HOME)/.conda-smithy/anaconda.token

# ─────────────────────────────────────────────────────────────────────────────
ifeq ($(IS_META),1)
# META-REPO LEVEL
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: all forge render render-retry readme list anaconda bot-check distribute debug status ci-status status-arch retag retag-all readme-status inspect rerun rerun-all add-macos add-macos-all variant-bump variant-trim root-bump root-trim

# Positional shorthand: "make <target> <arg>" behaves like
# "make <target> FEEDSTOCK=<arg>" for every target below that takes a
# package name. (status-arch's --failed flag flows through the same way
# since it's passed straight to the script either way.) A plain
# "make <target>" with no extra word is untouched -- FEEDSTOCK stays
# unset and targets fall back to their "operate on everything" mode.
PKG_TARGETS := render debug status ci-status status-arch retag inspect rerun add-macos
ifneq (,$(filter $(firstword $(MAKECMDGOALS)),$(PKG_TARGETS)))
  PKG_ARG := $(word 2,$(MAKECMDGOALS))
  ifneq ($(PKG_ARG),)
    FEEDSTOCK := $(PKG_ARG)
    $(eval $(PKG_ARG):;@:)
  endif
endif

all: forge render readme

forge:
	@conda install -c conda-forge -y \
	    conda-smithy conda-verify conda-package-handling anaconda-client

# Rerender all feedstocks, or one: make render FEEDSTOCK=fastjet-feedstock
# Prints one PASS/FAIL line per feedstock as it goes; full output for each
# goes to .render-logs/<feedstock>.log. Non-zero exit if anything failed.
render:
ifdef FEEDSTOCK
	@bash scripts/render_all.sh $(FEEDSTOCK)
else
	@bash scripts/render_all.sh
endif

# Re-run only the feedstocks that failed the last `make render`
# (from .render-logs/FAILED) — fix, then replay just those.
render-retry:
	@bash scripts/render_all.sh --retry

readme:
	@bash scripts/rerender_all.sh hep-forge

list:
	@find feedstocks -name "*.conda" ! -path "*/pkg_cache/*"

anaconda:
	@if [ ! -f "$(ANACONDA_TOKEN)" ]; then \
	    echo "Error: Anaconda token not found at $(ANACONDA_TOKEN)"; exit 1; \
	fi
	@for PKG in $$(find feedstocks -name "*.conda" ! -path "*/pkg_cache/*"); do \
	    conda-verify $$PKG && \
	    anaconda -t $$(cat $(ANACONDA_TOKEN)) upload --force $$PKG --label hep-forge; \
	done

bot-check:
	@python3 scripts/hep_bot/check_versions.py --dry-run

# Show feedstock status: tags, last AMD64/ARM64/macOS build dates, branches (= conda labels)
status:
ifdef FEEDSTOCK
	@bash scripts/feedstock_status.sh $(FEEDSTOCK)
else
	@bash scripts/feedstock_status.sh
endif

# Latest workflow run per feedstock, including failures and in-progress runs
# (make status only shows last SUCCESS dates). Non-zero exit if any latest
# run failed, so bots/cron can gate on it.
ci-status:
ifdef FEEDSTOCK
	@bash scripts/ci_status.sh $(FEEDSTOCK)
else
	@bash scripts/ci_status.sh
endif

# Latest run per feedstock broken down by job (amd64 | arm64 | publish),
# so you can see WHICH leg broke. --failed via ARGS="--failed".
status-arch:
ifdef FEEDSTOCK
	@bash scripts/status_arch.sh $(FEEDSTOCK)
else
	@bash scripts/status_arch.sh $(ARGS)
endif

# Move the latest tag to the default-branch tip and force-push it; the tag
# push fires the build. THE rebuild mechanism under tag-only CI (dispatch
# at an old tag fails: the workflow file at that ref predates the trigger).
retag:
ifndef FEEDSTOCK
	$(error Usage: make retag <name>   (e.g. make retag fastjet))
endif
	@bash scripts/retag_all.sh $(FEEDSTOCK)

retag-all:
	@bash scripts/retag_all.sh

# Refresh the feedstock status table in README.md (latest tag vs published
# version + per-arch state from anaconda.org). Run AFTER builds finish.
readme-status:
	@python3 scripts/update_readme_status.py

# Everything about ONE package in a single view: anaconda versions per
# arch, GitHub tags with a tag<->published sync verdict, recent workflow
# runs with per-job results, and error lines from failed jobs.
inspect:
ifndef FEEDSTOCK
	$(error Usage: make inspect <name>   (e.g. make inspect pythia))
endif
	@bash scripts/inspect_feedstock.sh $(FEEDSTOCK)

# Trigger a rebuild at the latest tag — a package name is required to prevent flooding runners
# Builds amd64 + linux-arm64 in parallel (one dispatch) for feedstocks on
# the unified autoupload.yml workflow. Uses the recipe AS OF THE TAG.
rerun:
ifndef FEEDSTOCK
	$(error Usage: make rerun <name>   (e.g. make rerun fastjet))
endif
	@bash scripts/rerun_tags.sh $(FEEDSTOCK)

# Rebuild EVERY feedstock at its latest tag. Builds only run on tag
# refs -- there is no branch/dev-build mode. Prefer `make retag-all` if
# recipes changed since tagging. Follow with `make status-arch`.
rerun-all:
	@bash scripts/rerun_tags.sh

# Migrate one feedstock's CI from separate amd64/arm64 workflows to the
# unified amd64 + linux-arm64 + macos-arm64 matrix workflow.
# A package name is required (see scripts/add_macos_arm64.sh for details).
add-macos:
ifndef FEEDSTOCK
	$(error Usage: make add-macos <name>   (e.g. make add-macos fastjet))
endif
	@bash scripts/add_macos_arm64.sh $(FEEDSTOCK)

# Migrate every feedstock not yet on the unified workflow, in one pass.
# Only rewrites CI plumbing (conda-forge.yml + autoupload.yml) -- does not
# commit, push, or fix per-package macOS build issues. Follow with
# `make render` to regenerate the resulting .ci_support scaffolding.
add-macos-all:
	@bash scripts/add_macos_arm64.sh --all

# Generic "keep minimal concurrent versions" helper for any variant key
# used across feedstocks' recipe/conda_build_config.yaml (root, libtorch,
# ...). Zip_keys-paired keys are trimmed/extended together automatically;
# adding a version to a zip-paired key needs --pair for its partner(s).
# Commits + pushes each affected feedstock directly.
#   make variant-bump KEY=root VERSION=6.40                          add + trim to newest 2
#   make variant-bump KEY=root VERSION=6.40 KEEP=3                   custom cap
#   make variant-bump KEY=root VERSION=6.40 PAIR="libtorch=2.8.0"    zip-paired key
#   make variant-trim KEY=root                                       just cap existing lists
variant-bump:
ifndef KEY
	$(error Usage: make variant-bump KEY=<name> VERSION=<value>   (e.g. make variant-bump KEY=root VERSION=6.40))
endif
ifndef VERSION
	$(error Usage: make variant-bump KEY=<name> VERSION=<value>   (e.g. make variant-bump KEY=root VERSION=6.40))
endif
	@python3 scripts/hep_bot/variant_versions.py --key $(KEY) $(VERSION) $(if $(KEEP),--keep $(KEEP)) $(if $(PAIR),--pair $(PAIR))

variant-trim:
ifndef KEY
	$(error Usage: make variant-trim KEY=<name>   (e.g. make variant-trim KEY=root))
endif
	@python3 scripts/hep_bot/variant_versions.py --key $(KEY) --trim $(if $(KEEP),--keep $(KEEP))

# Convenience aliases for ROOT specifically (manually versioned, dag.yaml:
# auto_update: false -- this is what you run by hand when a new release
# should roll out to the ~14 downstream consumers).
#   make root-bump VERSION=6.40
#   make root-trim
root-bump:
ifndef VERSION
	$(error Usage: make root-bump VERSION=<x.y>   (e.g. make root-bump VERSION=6.40))
endif
	@$(MAKE) variant-bump KEY=root VERSION=$(VERSION)

root-trim:
	@$(MAKE) variant-trim KEY=root

# Copy this Makefile into every feedstock directory
distribute:
	@for dir in $(FEEDSTOCKS); do \
	    cp Makefile $$dir/Makefile; \
	    echo "Distributed Makefile → $$dir"; \
	done

debug:
ifndef FEEDSTOCK
	$(error Usage: make debug <name>   (e.g. make debug fastjet))
endif
	@REPO="$(FEEDSTOCK)"; case "$$REPO" in *-feedstock) ;; *) REPO="$$REPO-feedstock" ;; esac; \
	cd "feedstocks/$$REPO" && \
	OUTPUT_ID=$$(conda render . --output 2>&1 \
	    | grep -E '\.(tar\.bz2|conda)$$' | sort | tail -1 | xargs -r basename); \
	if [ -n "$$OUTPUT_ID" ]; then \
	    conda debug . --output-id "$$OUTPUT_ID"; \
	else \
	    conda debug .; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
else
# FEEDSTOCK LEVEL  (this file was distributed into a single feedstock)
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: all forge render list anaconda debug

all: forge render list

forge:
	@conda install -c conda-forge -y \
	    conda-smithy conda-verify conda-package-handling anaconda-client

render:
	@conda smithy rerender --no-check-uptodate
	@echo "!Makefile" >> .gitignore
	@echo "!.github"  >> .gitignore
	@git add .gitignore 2>/dev/null || true
	@find . -maxdepth 3 -name conda-build.yml -delete
	@rm -rf .scripts

list:
	@find build_artifacts -name "*.conda" ! -path "*/pkg_cache/*" 2>/dev/null || echo "(no build_artifacts yet)"

anaconda:
	@if [ ! -f "$(ANACONDA_TOKEN)" ]; then \
	    echo "Error: Anaconda token not found at $(ANACONDA_TOKEN)"; exit 1; \
	fi
	@for PKG in $$(find build_artifacts -name "*.conda" ! -path "*/pkg_cache/*" 2>/dev/null); do \
	    conda-verify $$PKG && \
	    anaconda -t $$(cat $(ANACONDA_TOKEN)) upload --force $$PKG --label hep-forge; \
	done

debug:
	@OUTPUT_ID=$$(conda render . --output 2>&1 \
	    | grep -E '\.(tar\.bz2|conda)$$' | sort | tail -1 | xargs -r basename); \
	if [ -n "$$OUTPUT_ID" ]; then \
	    conda debug . --output-id "$$OUTPUT_ID"; \
	else \
	    conda debug .; \
	fi

endif
