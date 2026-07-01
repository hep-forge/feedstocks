# hep-feedstocks / hep-forge feedstock Makefile
#
# Self-detecting: works at the meta-repo root AND when copied into a single feedstock.
#   - Root level  (feedstocks/ dir present):  targets operate on ALL feedstocks
#   - Feedstock   (recipe/ dir present):       targets operate on THIS feedstock
#
# Meta-repo usage:
#   make forge          Install conda-smithy + tools
#   make render         Rerender all feedstocks (or: make render FEEDSTOCK=fastjet-feedstock)
#                       one PASS/FAIL line per feedstock; full logs in .render-logs/
#   make render-retry   Re-run only the feedstocks that failed the last render
#   make readme         Regenerate all README.md files (hep-forge badges/links)
#   make list           List all built .conda packages across feedstocks
#   make anaconda       Upload all built packages to hep-forge channel
#   make bot-check      Dry-run upstream version check (hep-bot)
#   make distribute     Copy this Makefile into every feedstock
#   make debug FEEDSTOCK=<name>  Debug one feedstock build
#   make status          Tags/branches + last AMD64/ARM64/macOS build dates
#   make rerun FEEDSTOCK=<name>    Trigger a rebuild (amd64+arm64+macos-arm64 in parallel, if migrated)
#   make add-macos FEEDSTOCK=<name>  Migrate one feedstock's CI to the amd64+arm64+macos-arm64 matrix workflow
#   make add-macos-all   Migrate every feedstock not yet on the unified workflow
#   make root-bump VERSION=<x.y>  Roll a new ROOT version out to all consumers, trim to newest 2
#   make root-trim       Cap all consumers' root: lists at the newest 2, no new version
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

.PHONY: all forge render render-retry readme list anaconda bot-check distribute debug status rerun add-macos add-macos-all root-bump root-trim

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
	@python3 scripts/rerender_all.sh hep-forge

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

# Trigger a rebuild at the latest tag — FEEDSTOCK= is required to prevent flooding runners
# Builds amd64 + linux-arm64 + macos-arm64 in parallel (one dispatch) for
# feedstocks already migrated to the unified autoupload.yml workflow.
rerun:
ifndef FEEDSTOCK
	$(error Usage: make rerun FEEDSTOCK=<feedstock-name>   (e.g. make rerun FEEDSTOCK=fastjet-feedstock))
endif
	@bash scripts/rerun_tags.sh $(FEEDSTOCK)

# Migrate one feedstock's CI from separate amd64/arm64 workflows to the
# unified amd64 + linux-arm64 + macos-arm64 matrix workflow.
# FEEDSTOCK= is required (see scripts/add_macos_arm64.sh for details).
add-macos:
ifndef FEEDSTOCK
	$(error Usage: make add-macos FEEDSTOCK=<feedstock-name>   (e.g. make add-macos FEEDSTOCK=fastjet-feedstock))
endif
	@bash scripts/add_macos_arm64.sh $(FEEDSTOCK)

# Migrate every feedstock not yet on the unified workflow, in one pass.
# Only rewrites CI plumbing (conda-forge.yml + autoupload.yml) -- does not
# commit, push, or fix per-package macOS build issues. Follow with
# `make render` to regenerate the resulting .ci_support scaffolding.
add-macos-all:
	@bash scripts/add_macos_arm64.sh --all

# ROOT is manually versioned (dag.yaml: auto_update: false). When a new
# ROOT release should roll out, this adds it to every downstream
# feedstock's recipe/conda_build_config.yaml `root:` variant list and
# drops the oldest, keeping (by default) the newest 2 concurrent
# versions. Commits + pushes each affected feedstock directly.
#   make root-bump VERSION=6.40            add 6.40, trim to newest 2
#   make root-bump VERSION=6.40 KEEP=3      custom cap
#   make root-trim                          just cap existing lists, no new version
root-bump:
ifndef VERSION
	$(error Usage: make root-bump VERSION=<x.y>   (e.g. make root-bump VERSION=6.40))
endif
	@python3 scripts/hep_bot/root_versions.py $(VERSION) $(if $(KEEP),--keep $(KEEP))

root-trim:
	@python3 scripts/hep_bot/root_versions.py --trim $(if $(KEEP),--keep $(KEEP))

# Copy this Makefile into every feedstock directory
distribute:
	@for dir in $(FEEDSTOCKS); do \
	    cp Makefile $$dir/Makefile; \
	    echo "Distributed Makefile → $$dir"; \
	done

debug:
ifndef FEEDSTOCK
	$(error Usage: make debug FEEDSTOCK=<feedstock-name>)
endif
	@cd feedstocks/$(FEEDSTOCK) && \
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
