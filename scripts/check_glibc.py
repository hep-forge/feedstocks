#!/usr/bin/env python3
"""Audit published hep-forge packages for GLIBC symbol-version leaks.

conda-forge's whole point of pinning an old sysroot (c_stdlib_version,
usually 2.17) is portability: a package built against it should run on
any host with glibc >= that pin, not just on whatever glibc happens to
be on the CI runner that built it. A build that discards conda-build's
own CFLAGS/CXXFLAGS (or bypasses its bundled autotools toolchain) can
silently link against newer glibc symbol versions than the pin,
producing a package that fails with "version `GLIBC_x.y' not found" on
any older host -- exactly the bug found in lhapdf-feedstock (2026-07-08,
__isoc23_strtol requiring GLIBC_2.38 from a stale bundled ./configure).

This downloads each package's latest linux-64 build (the one everyone's
host is most likely to run), extracts every non-symlink *.so*, and
reports the highest GLIBC_x.y symbol version referenced anywhere inside
-- flagging anything above the pin (read from that feedstock's own
conda_build_config.yaml `c_stdlib_version`, default 2.17 if unset).

Usage:
  python3 scripts/check_glibc.py                    # every published package, linux-64
  python3 scripts/check_glibc.py pythia root lhapdf  # just these
  python3 scripts/check_glibc.py --arch linux-aarch64
  python3 scripts/check_glibc.py --workers 4         # gentler on bandwidth/disk

Needs `objdump` and `zstd` on PATH (both standard on any conda-forge
build image / most Linux dev boxes). Read-only: makes no changes to
anaconda.org, this repo, or any feedstock.
"""
import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

API = "https://api.anaconda.org"
ORG = "hep-forge"
DEFAULT_PIN = "2.17"


def fetch(path: str):
    with urllib.request.urlopen(f"{API}{path}", timeout=30) as resp:
        return json.load(resp)


def version_key(version: str):
    return [int(p) if p.isdigit() else p for p in re.split(r"[._-]", version)]


def latest_file(pkg: str, arch: str):
    files = fetch(f"/package/{ORG}/{pkg}").get("files", [])
    cands = [f for f in files if f.get("attrs", {}).get("subdir") == arch]
    if not cands:
        return None
    cands.sort(key=lambda f: (version_key(f.get("version", "")), f.get("attrs", {}).get("timestamp", 0)))
    return cands[-1]


def stdlib_pin(pkg: str) -> str:
    path = f"feedstocks/{pkg}-feedstock/recipe/conda_build_config.yaml"
    if not os.path.exists(path):
        return DEFAULT_PIN
    text = open(path).read()
    m = re.search(r"c_stdlib_version:\s*\n\s*-\s*[\"']?([\d.]+)", text)
    return m.group(1) if m else DEFAULT_PIN


def glibc_tuple(v: str):
    return tuple(int(p) for p in v.split("."))


def max_glibc_in_package(basename: str, download_url: str, tmpdir: str):
    """Download one .conda, extract every real (non-symlink) *.so*, return
    (max_glibc_version_str, offending_file) or (None, None) if clean/no libs."""
    local = os.path.join(tmpdir, os.path.basename(basename))
    urllib.request.urlretrieve(f"https:{download_url}" if download_url.startswith("//") else download_url, local)

    extract_dir = local + ".x"
    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(local) as z:
        pkg_member = next((n for n in z.namelist() if n.startswith("pkg-") and n.endswith(".tar.zst")), None)
        if pkg_member is None:
            return None, None
        z.extract(pkg_member, extract_dir)

    tar_path = os.path.join(extract_dir, pkg_member)
    subprocess.run(["tar", "--zstd", "-xf", tar_path, "-C", extract_dir], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    worst_ver, worst_file = None, None
    for root, _dirs, fnames in os.walk(extract_dir):
        for fn in fnames:
            if ".so" not in fn:
                continue
            fpath = os.path.join(root, fn)
            if os.path.islink(fpath):
                continue
            out = subprocess.run(["objdump", "-T", fpath], capture_output=True, text=True).stdout
            vers = re.findall(r"GLIBC_([\d.]+)", out)
            if not vers:
                continue
            local_max = max(vers, key=glibc_tuple)
            if worst_ver is None or glibc_tuple(local_max) > glibc_tuple(worst_ver):
                worst_ver, worst_file = local_max, os.path.relpath(fpath, extract_dir)

    shutil.rmtree(extract_dir, ignore_errors=True)
    os.remove(local)
    return worst_ver, worst_file


def check_one(pkg: str, arch: str, tmpdir: str):
    try:
        f = latest_file(pkg, arch)
        if f is None:
            return pkg, "SKIP", f"no {arch} build published", None
        pin = stdlib_pin(pkg)
        worst_ver, worst_file = max_glibc_in_package(f["basename"], f["download_url"], tmpdir)
        if worst_ver is None:
            return pkg, "OK", f"no shared libs (or none link glibc) -- version {f.get('version')}", None
        status = "OK" if glibc_tuple(worst_ver) <= glibc_tuple(pin) else "VIOLATION"
        detail = f"max GLIBC_{worst_ver} vs pin {pin} ({f.get('version')}) in {worst_file}"
        return pkg, status, detail, worst_ver
    except Exception as e:  # noqa: BLE001 -- best-effort audit, keep going on any single-package failure
        return pkg, "ERROR", str(e), None


def all_package_names():
    return sorted(
        os.path.basename(d)[: -len("-feedstock")]
        for d in os.listdir("feedstocks")
        if d.endswith("-feedstock") and os.path.isdir(f"feedstocks/{d}/recipe")
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("packages", nargs="*", help="package names to check (default: every feedstock)")
    ap.add_argument("--arch", default="linux-64", choices=["linux-64", "linux-aarch64"])
    ap.add_argument("--workers", type=int, default=8, help="parallel downloads (default 8)")
    args = ap.parse_args()

    pkgs = args.packages or all_package_names()
    print(f"Checking {len(pkgs)} package(s) on {args.arch} (pin read per-package from conda_build_config.yaml, default {DEFAULT_PIN})...\n")

    results = []
    with tempfile.TemporaryDirectory(prefix="glibc-audit-") as tmpdir, \
         concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(check_one, p, args.arch, tmpdir): p for p in pkgs}
        for fut in concurrent.futures.as_completed(futs):
            pkg, status, detail, _ = fut.result()
            results.append((pkg, status, detail))
            print(f"{status:10s} {pkg:24s} {detail}")

    violations = [r for r in results if r[1] == "VIOLATION"]
    errors = [r for r in results if r[1] == "ERROR"]
    print(f"\n{len(results)} checked, {len(violations)} violation(s), {len(errors)} error(s), "
          f"{sum(1 for r in results if r[1] == 'SKIP')} skipped (no {args.arch} build)")
    if violations:
        print("\nVIOLATIONS (fix in build.sh -- likely a CFLAGS/CXXFLAGS overwrite or bundled/stale ./configure):")
        for pkg, _status, detail in violations:
            print(f"  {pkg}: {detail}")
        sys.exit(1)


if __name__ == "__main__":
    main()
