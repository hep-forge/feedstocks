#!/usr/bin/env python3
"""Map hep-forge's internal package dependency graph.

Parses every feedstock's recipe/meta.yaml requirements: block, keeping only
references to OTHER hep-forge packages (conda-forge externals like numpy or
zlib are dropped since they carry no build-order constraint within this
repo). From that graph it derives a "phase" per package: the length of its
longest internal dependency chain. Phase 0 packages have no hep-forge
dependencies at all; phase N packages need at least one phase N-1 package.

This is a different thing from any hand-planned rollout sequence for a
specific stack subset (e.g. the EIC-stack phases discussed in project
memory) -- it's a structural, always-current view of the full feedstock set,
recomputed from the recipes each time you run it.

Usage:
    python3 scripts/dep_graph.py                 full phase report
    python3 scripts/dep_graph.py <pkg>            one package's deps/dependents
    python3 scripts/dep_graph.py --json           machine-readable dump
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEEDSTOCKS = ROOT / "feedstocks"


def parse_internal_deps(name_set):
    deps = {}
    for d in sorted(os.listdir(FEEDSTOCKS)):
        if not d.endswith("-feedstock"):
            continue
        pkg = d[: -len("-feedstock")]
        meta_path = FEEDSTOCKS / d / "recipe" / "meta.yaml"
        if not meta_path.exists():
            continue
        content = meta_path.read_text(encoding="utf-8", errors="ignore")

        m = re.search(r"\nrequirements:\n(.*?)(\n\S|\Z)", content, re.S)
        section = m.group(1) if m else ""

        tokens = set()
        for line in section.splitlines():
            line = line.strip()
            if not line.startswith("-"):
                continue
            item = line[1:].split("#")[0].strip()
            mtok = re.match(r"([A-Za-z0-9_.\-]+)", item)
            if mtok:
                tokens.add(mtok.group(1).lower())

        deps[pkg] = sorted(t for t in tokens if t in name_set and t != pkg)
    return deps


def compute_phases(deps):
    memo, visiting, cycles = {}, set(), []

    def phase(p):
        if p in memo:
            return memo[p]
        if p in visiting:
            cycles.append(p)
            return 0
        visiting.add(p)
        d = deps.get(p, [])
        memo[p] = 0 if not d else 1 + max(phase(x) for x in d)
        visiting.discard(p)
        return memo[p]

    for p in deps:
        phase(p)
    return memo, cycles


def transitive(name, edges, seen=None):
    seen = seen if seen is not None else set()
    for d in edges.get(name, []):
        if d not in seen:
            seen.add(d)
            transitive(d, edges, seen)
    return seen


def build_graph():
    names = sorted(
        d[: -len("-feedstock")] for d in os.listdir(FEEDSTOCKS) if d.endswith("-feedstock")
    )
    name_set = set(names)
    deps = parse_internal_deps(name_set)
    for p in names:
        deps.setdefault(p, [])
    phase, cycles = compute_phases(deps)
    dependents = {p: [] for p in names}
    for p, dl in deps.items():
        for d in dl:
            dependents.setdefault(d, []).append(p)
    return names, deps, dependents, phase, cycles


def print_full_report(names, deps, dependents, phase, cycles):
    max_phase = max(phase.values())
    from collections import defaultdict

    by_phase = defaultdict(list)
    for p in names:
        by_phase[phase[p]].append(p)

    for ph in range(max_phase + 1):
        pkgs = sorted(by_phase[ph])
        print(f"=== Phase {ph} ({len(pkgs)}) ===")
        print(", ".join(pkgs))
        print()

    if cycles:
        print(f"WARNING: cycle(s) detected involving: {sorted(set(cycles))}")
    else:
        print(f"{len(names)} packages, {max_phase + 1} phases, no cycles.")


def print_package(name, deps, dependents, phase, all_names):
    if name not in phase:
        print(f"'{name}' is not a hep-forge feedstock. Known packages:")
        print(", ".join(all_names))
        sys.exit(1)

    up = transitive(name, deps)
    down = transitive(name, dependents)

    print(f"{name}  (phase {phase[name]})")
    print()
    print(f"directly needs ({len(deps[name])}):")
    print("  " + (", ".join(deps[name]) if deps[name] else "(nothing internal)"))
    print()
    print(f"directly needed by ({len(dependents[name])}):")
    print("  " + (", ".join(dependents[name]) if dependents[name] else "(nothing -- leaf consumer)"))
    print()
    print(f"full upstream chain ({len(up)}):")
    print("  " + (", ".join(sorted(up)) if up else "(none)"))
    print()
    print(f"full downstream chain ({len(down)}):")
    print("  " + (", ".join(sorted(down)) if down else "(none)"))


def main():
    names, deps, dependents, phase, cycles = build_graph()

    args = sys.argv[1:]
    if "--json" in args:
        out = {
            p: {"phase": phase[p], "deps": deps[p], "dependents": sorted(dependents[p])}
            for p in names
        }
        print(json.dumps(out, indent=2))
        return

    if args:
        print_package(args[0].strip().lower(), deps, dependents, phase, names)
    else:
        print_full_report(names, deps, dependents, phase, cycles)


if __name__ == "__main__":
    main()
