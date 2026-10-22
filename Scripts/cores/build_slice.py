#!/usr/bin/env python3
"""Build one Azahar or Dolphin core slice outside the app, cached by a content key.

  build_slice.py <azahar|dolphin> <ios|ios-sim|tvos|tvos-sim> [--print-key] [--force]
                 [--cache-dir DIR] [--xcframework]

Key: sha256 over the core submodule HEAD and `git submodule status --recursive` inside it,
the wrapped build script and CMake toolchain contents (Azahar's CMAKE_OPTIONS live in its
script), Dolphin's DOL_FULL_LTO / DOL_PGO / DOL_PGO_PROFILE and the PGO profile it would use,
`xcodebuild -version`, the slice SDK version and, for Azahar, the MoltenVK static slice it
configures against. `--print-key` prints it (CI cache keys).

Dolphin's submodule is also iCube's app repo, whose app code, docs and prebuilt build/ binaries
change far more often than the engine. So Dolphin keys on the tree hashes of only the paths the
PVlibDolphin CMake build reads (DOLPHIN_BUILD_PATHS) instead of its HEAD, and its uncommitted
edits count only under those paths.

Fast path: the full key scans every working tree in the core and its nested submodules for
uncommitted edits, which took ~10 minutes on a cold disk (all I/O wait). So a normal run first
compares the cheap inputs (core HEAD or Dolphin's source trees, the nested gitlinks that HEAD
records, script, toolchain, Xcode, SDK, MoltenVK, Dolphin's flags) with what the last
preparation of this checkout recorded (<cache>/<core>/<slice>/prepared-<checkout>.json). If
they match and that cache entry still exists, it reuses it without scanning. `--strict` (or PV_CORE_STRICT=1) always scans: use it
after editing engine sources in place. `--force` and `--print-key` always scan too.

Cache: $PV_CORE_CACHE or ~/Library/Caches/Provenance/cores, laid out as
<core>/<slice>/<key[:12]>/<Product>-<slice>.framework + stamp.json. On a hit the legacy output
path (Cores/Azahar/build/xcframework/PVlibAzahar-<slice>.framework,
Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin-<slice>.framework) becomes a symlink
into the cache, so PVAzahar's PVAZAHAR_ARCHIVE path and PVDolphin's references don't change.
On a miss the wrapped builder builds that one slice (its per-platform methods, not its main(),
which would also repack the xcframework), the product moves into the cache and is linked.
--xcframework repacks <Product>.xcframework for distribution; Dolphin also repacks it when it
is missing, since SwiftPM resolves the xcframework at planning time.

Python 3.9 compatible (Dolphin's Xcode phase runs /usr/bin/python3). Azahar's builder needs
3.10+, so it runs in a separate interpreter (PV_PYTHON3, Homebrew python3, python3.1x).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Mapping, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE = Path.home() / "Library" / "Caches" / "Provenance" / "cores"
KEEP_ENTRIES = 2
HOMEBREW_BIN = "/opt/homebrew/bin"

SLICES: Dict[str, Dict[str, str]] = {
    "ios": {"cmake": "OS64", "sdk": "iphoneos", "mvk": "ios-arm64"},
    "ios-sim": {"cmake": "SIMULATORARM64", "sdk": "iphonesimulator", "mvk": "ios-arm64_x86_64-simulator"},
    "tvos": {"cmake": "TVOS", "sdk": "appletvos", "mvk": "tvos-arm64_arm64e"},
    "tvos-sim": {"cmake": "SIMULATOR_TVOS", "sdk": "appletvsimulator", "mvk": "tvos-arm64_x86_64-simulator"},
}

SLICE_FOR_PLATFORM_NAME: Dict[str, str] = {
    "iphoneos": "ios",
    "iphonesimulator": "ios-sim",
    "appletvos": "tvos",
    "appletvsimulator": "tvos-sim",
}

# (SupportedPlatform, SupportedPlatformVariant) as an xcframework's Info.plist records them.
SLICE_PLATFORMS: Dict[str, Tuple[str, Optional[str]]] = {
    "ios": ("ios", None),
    "ios-sim": ("ios", "simulator"),
    "tvos": ("tvos", None),
    "tvos-sim": ("tvos", "simulator"),
}

# Everything in dolphin-ios that BuildiOSXCFramework.py's CMake build of PVlibDolphin reads.
# Source/CMakeLists.txt adds only Core and, for IOS, iOS/Library; every nested submodule lives
# under Externals, so its gitlinks are in that tree; Core generates AchievementApprovedHash.h
# from ApprovedInis.json. The builder script, toolchain and PGO profile are hashed on their own.
DOLPHIN_BUILD_PATHS: Tuple[str, ...] = (
    "CMakeLists.txt",
    "CMake",
    "Externals",
    "Source/CMakeLists.txt",
    "Source/Core",
    "Source/iOS/Library",
    "Data/Sys/ApprovedInis.json",
)

Runner = Callable[[List[str], Optional[Path]], str]
Builder = Callable[["CoreSpec", str], None]


@dataclass(frozen=True)
class CoreSpec:
    name: str
    product: str
    submodule: Path
    script: Path
    toolchain: Path
    legacy_dir: Path
    env_flags: Tuple[str, ...]
    moltenvk: Optional[Path]
    build_paths: Tuple[str, ...] = ()  # empty: the whole submodule is a build input


def core_specs(repo: Path) -> Dict[str, CoreSpec]:
    return {
        "azahar": CoreSpec(
            name="azahar",
            product="PVlibAzahar",
            submodule=repo / "Cores/Azahar/azahar",
            script=repo / "Cores/Azahar/build_azahar_core.py",
            toolchain=repo / "Cores/Azahar/cmake/ios.toolchain.cmake",
            legacy_dir=repo / "Cores/Azahar/build/xcframework",
            env_flags=(),
            moltenvk=repo / "MoltenVK/MoltenVK/static/MoltenVK.xcframework",
        ),
        "dolphin": CoreSpec(
            name="dolphin",
            product="PVlibDolphin",
            submodule=repo / "Cores/Dolphin/dolphin-ios",
            script=repo / "Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py",
            toolchain=repo / "Cores/Dolphin/dolphin-ios/Externals/ios-cmake/ios.toolchain.cmake",
            legacy_dir=repo / "Cores/Dolphin/dolphin-ios/build/xcframework",
            env_flags=("DOL_FULL_LTO", "DOL_PGO", "DOL_PGO_PROFILE"),
            moltenvk=None,
            build_paths=DOLPHIN_BUILD_PATHS,
        ),
    }


def log(message: str) -> None:
    print(f"build_slice: {message}", file=sys.stderr, flush=True)


def default_runner(cmd: List[str], cwd: Optional[Path] = None) -> str:
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=True, capture_output=True,
                            text=True, errors="surrogateescape")
    return result.stdout.strip()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_submodule_status(text: str) -> str:
    """'<flag><sha> <path> (<describe>)' -> '<sha> <path>', sorted. Init state and describe drop out."""
    entries = []
    for line in text.splitlines():
        if not line.strip():
            continue
        body = line[1:] if line[:1] in " +-U" else line
        parts = body.split()
        if len(parts) >= 2:
            entries.append(f"{parts[0]} {parts[1]}")
    return "\n".join(sorted(entries))


def dolphin_pgo(spec: CoreSpec, env: Mapping[str, str]) -> Tuple[str, Optional[Path]]:
    """(mode, profile) exactly as BuildiOSXCFramework.resolve_pgo decides them."""
    default = spec.submodule / "pgo" / "icube.profdata"
    mode = env.get("DOL_PGO", "").strip().lower()
    explicit = env.get("DOL_PGO_PROFILE", "").strip()
    if mode in ("", "auto"):
        return ("use", default) if default.exists() else ("off", None)
    if mode == "use" and not explicit:
        return mode, default
    return mode, (Path(explicit) if explicit else None)


def affects_build(path: str, build_paths: Tuple[str, ...] = ()) -> bool:
    """False for documentation (a repo's top-level docs/ and any Markdown file) and, when
    build_paths is given, for anything outside those paths.

    Uncommitted edits there cannot change a built slice, but they used to bust the key: an
    untracked docs/superpowers/baselines/ folder in dolphin-ios forced a Dolphin rebuild and
    relink. Committed changes still count through the submodule commit or source trees.
    """
    path = path.strip('"')
    if path.startswith("docs/") or path.lower().endswith(".md"):
        return False
    return not build_paths or any(path == p or path.startswith(p + "/") for p in build_paths)


def build_relevant_porcelain(porcelain: str, build_paths: Tuple[str, ...] = ()) -> str:
    kept = []
    for line in porcelain.splitlines():
        paths = line[3:].split(" -> ")  # renames list "old -> new"
        if any(affects_build(path, build_paths) for path in paths):
            kept.append(line)
    return "\n".join(kept)


def build_relevant_diff(diff: str, build_paths: Tuple[str, ...] = ()) -> str:
    blocks = re.split(r"(?m)^(?=diff --git )", diff)
    kept = []
    for block in blocks:
        match = re.match(r"diff --git a/(\S+) b/(\S+)", block)
        if match is None or any(affects_build(path, build_paths) for path in match.groups()):
            kept.append(block)
    return "".join(kept)


def worktree_state(spec: CoreSpec, runner: Runner) -> str:
    """Hash of uncommitted edits in the core submodule and its nested submodules."""
    status = runner(["git", "-C", str(spec.submodule), "submodule", "status", "--recursive"], None)
    repos = [spec.submodule]
    for line in status.splitlines():
        body = line[1:] if line[:1] in " +-U" else line
        parts = body.split()
        if len(parts) >= 2 and line[:1] != "-":
            repos.append(spec.submodule / parts[1])
    digest = hashlib.sha256()
    for repo in repos:
        # Nested repos sit under the build paths, so only the core repo itself is narrowed. The
        # pathspec keeps git from scanning (and diffing whole rewritten dylibs in) the rest.
        build_paths = spec.build_paths if repo == spec.submodule else ()
        pathspec = ["--", *build_paths] if build_paths else []
        porcelain = build_relevant_porcelain(runner(
            ["git", "-C", str(repo), "status", "--porcelain=v1", "--untracked-files=all",
             "--ignore-submodules=none", *pathspec], None), build_paths)
        diff = build_relevant_diff(runner(
            ["git", "-C", str(repo), "diff", "HEAD", "--binary", *pathspec], None), build_paths)
        if not porcelain and not diff:
            continue  # clean (or not checked out): contributes nothing, so init state doesn't matter
        rel = repo.relative_to(spec.submodule)
        digest.update(f"{rel}\0{porcelain}\0".encode("utf-8", "surrogateescape"))
        digest.update(diff.encode("utf-8", "surrogateescape"))
        for line in porcelain.splitlines():
            if line.startswith("?? "):
                untracked = repo / line[3:].strip('"')
                if untracked.is_file():
                    digest.update(f"{line}\0{file_hash(untracked)}\0".encode("utf-8", "surrogateescape"))
    return digest.hexdigest()


def source_trees(spec: CoreSpec, runner: Runner) -> str:
    """'<path> <object id>' for each build path in the core's HEAD (object reads, no worktree stat)."""
    revs = [f"HEAD:{path}" for path in spec.build_paths]
    try:
        ids = runner(["git", "-C", str(spec.submodule), "rev-parse", *revs], None).splitlines()
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"build_slice: {spec.submodule} HEAD lacks one of {', '.join(spec.build_paths)}; "
                         f"update the {spec.name} build paths in build_slice.py ({error})")
    if len(ids) != len(revs):
        raise SystemExit(f"build_slice: expected {len(revs)} object ids from git rev-parse, got {len(ids)}")
    return "\n".join(f"{path} {oid}" for path, oid in zip(spec.build_paths, ids))


def cheap_inputs(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> Dict[str, str]:
    """Key inputs that need no working-tree scan: a few file hashes and git object reads."""
    sl = SLICES[slice_name]
    inputs = {
        "core": spec.name,
        "slice": slice_name,
        "script": file_hash(spec.script),
        "toolchain": file_hash(spec.toolchain),
        "xcode": runner(["xcodebuild", "-version"], None),
        "sdk": runner(["xcrun", "--sdk", sl["sdk"], "--show-sdk-version"], None),
    }
    if spec.build_paths:
        inputs["source_trees"] = source_trees(spec, runner)
    else:
        inputs["submodule_head"] = runner(["git", "-C", str(spec.submodule), "rev-parse", "HEAD"], None)
    if spec.name == "dolphin":
        inputs["env:DOL_FULL_LTO"] = "1" if env.get("DOL_FULL_LTO") == "1" else ""
        mode, profile = dolphin_pgo(spec, env)
        # "use" with a missing profile and "off" both build without one.
        has_profile = mode == "use" and profile is not None and profile.exists()
        inputs["pgo_mode"] = "generate" if mode == "generate" else ("use" if has_profile else "off")
        inputs["pgo_profile"] = file_hash(profile) if has_profile and profile is not None else ""
    if spec.moltenvk is not None:
        inputs["moltenvk"] = file_hash(spec.moltenvk / sl["mvk"] / "libMoltenVK.a")
    return inputs


def recorded_gitlinks(spec: CoreSpec, runner: Runner) -> str:
    """Nested submodule commits recorded in the core's HEAD tree (object reads, no worktree stat)."""
    tree = runner(["git", "-C", str(spec.submodule), "ls-tree", "-r", "HEAD"], None)
    return "\n".join(sorted(line for line in tree.splitlines() if " commit " in line))


def fast_fingerprint(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> str:
    inputs = cheap_inputs(spec, slice_name, runner, env)
    inputs["recorded_gitlinks"] = recorded_gitlinks(spec, runner)
    return hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()


def key_inputs(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> Dict[str, str]:
    inputs = cheap_inputs(spec, slice_name, runner, env)
    inputs["submodule_tree"] = normalize_submodule_status(
        runner(["git", "-C", str(spec.submodule), "submodule", "status", "--recursive"], None))
    inputs["worktree"] = worktree_state(spec, runner)
    return inputs


def compute_key(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> str:
    blob = json.dumps(key_inputs(spec, slice_name, runner, env), sort_keys=True).encode()
    return hashlib.sha256(blob).hexdigest()


def framework_name(spec: CoreSpec, slice_name: str) -> str:
    return f"{spec.product}-{slice_name}.framework"


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def link_legacy(spec: CoreSpec, slice_name: str, target: Path) -> Path:
    legacy = spec.legacy_dir / framework_name(spec, slice_name)
    remove_path(legacy)
    legacy.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(str(target), str(legacy))
    return legacy


def prepare_headers(spec: CoreSpec, framework: Path) -> None:
    """Expose the selected Azahar slice's headers at a stable package search path."""
    if spec.name != "azahar":
        return
    source = framework / "Headers"
    if not source.is_dir():
        raise SystemExit(f"build_slice: missing native headers: {source}")
    destination = spec.legacy_dir.parent / "headers"
    remove_path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(str(source.resolve()), str(destination))


def prune_entries(slice_dir: Path, keep: int, current: Path) -> None:
    entries = [p for p in slice_dir.iterdir() if p.is_dir() and p != current]
    entries.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    for stale in entries[max(0, keep - 1):]:
        log(f"pruning old cache entry {stale}")
        shutil.rmtree(stale)


def prepared_record_path(spec: CoreSpec, slice_name: str, cache: Path) -> Path:
    """One record per checkout: worktrees and clones share the cache but not their sources."""
    checkout = hashlib.sha256(str(spec.submodule.resolve()).encode()).hexdigest()[:12]
    return cache / spec.name / slice_name / f"prepared-{checkout}.json"


def read_prepared(path: Path) -> Dict[str, str]:
    try:
        record = json.loads(path.read_text())
    except (OSError, ValueError):
        return {}
    return record if isinstance(record, dict) else {}


def write_prepared(path: Path, record: Mapping[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(dict(record), indent=2, sort_keys=True) + "\n")


def is_cached(spec: CoreSpec, slice_name: str, cache: Path, key: str) -> bool:
    entry = cache / spec.name / slice_name / key[:12]
    return (entry / framework_name(spec, slice_name)).is_dir() and (entry / "stamp.json").is_file()


def xcframework_has_slice(spec: CoreSpec, slice_name: str) -> bool:
    plist = spec.legacy_dir / f"{spec.product}.xcframework" / "Info.plist"
    try:
        with plist.open("rb") as handle:
            libraries = plistlib.load(handle).get("AvailableLibraries", [])
    except (OSError, ValueError, plistlib.InvalidFileException):
        return False
    platform, variant = SLICE_PLATFORMS[slice_name]
    # Dolphin names each library <Product>-<slice>.framework; Azahar's are all <Product>.framework,
    # so match on the platform the xcframework records as well.
    return any(lib.get("LibraryPath") == framework_name(spec, slice_name)
               or (lib.get("SupportedPlatform") == platform and lib.get("SupportedPlatformVariant") == variant)
               for lib in libraries)


def needs_xcframework(spec: CoreSpec, slice_name: str, produced: bool, requested: bool) -> bool:
    """Azahar links the per-slice archive; Dolphin links the multi-slice xcframework at planning time."""
    if requested:
        return True
    if spec.name != "dolphin":
        return False
    return produced or not xcframework_has_slice(spec, slice_name)


def ensure_slice(spec: CoreSpec, slice_name: str, cache: Path, key: str, inputs: Mapping[str, str],
                 force: bool, builder: Builder) -> Path:
    entry = cache / spec.name / slice_name / key[:12]
    framework = entry / framework_name(spec, slice_name)
    stamp = entry / "stamp.json"
    if not force and is_cached(spec, slice_name, cache, key):
        link_legacy(spec, slice_name, framework)
        log(f"{spec.name} {slice_name}: cache hit {key[:12]}")
        return framework

    legacy = spec.legacy_dir / framework_name(spec, slice_name)
    remove_path(legacy)  # the builders rmtree() this path, which fails on a symlink
    log(f"{spec.name} {slice_name}: cache miss {key[:12]}; building")
    builder(spec, slice_name)
    if legacy.is_symlink() or not legacy.is_dir():
        raise SystemExit(f"build_slice: {legacy} was not produced by the {spec.name} builder")

    remove_path(entry)
    entry.mkdir(parents=True)
    shutil.move(str(legacy), str(framework))
    stamp.write_text(json.dumps({
        "key": key,
        "inputs": dict(inputs),
        "built": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    }, indent=2, sort_keys=True) + "\n")
    link_legacy(spec, slice_name, framework)
    prune_entries(entry.parent, KEEP_ENTRIES, entry)
    log(f"{spec.name} {slice_name}: cached {framework}")
    return framework


AZAHAR_BUILD = (
    "import sys; sys.path.insert(0, sys.argv[1]); import build_azahar_core as b; "
    "builder = b.AzaharBuilder(verbose=True); builder.build_platform(sys.argv[2]); "
    "b.write_gitlink_stamps([sys.argv[2]])"
)
AZAHAR_XCFRAMEWORK = (
    "import sys; sys.path.insert(0, sys.argv[1]); import build_azahar_core as b; "
    "b.AzaharBuilder(verbose=True).create_xcframework()"
)
DOLPHIN_BUILD = (
    "import sys; sys.path.insert(0, sys.argv[1]); import BuildiOSXCFramework as d; "
    "builder = d.DolphinBuilder(verbose=True); p = sys.argv[2]; ok = builder.build_platform(p); "
    "sys.exit(1) if ok is False or p not in builder.dylibs else builder.create_framework(builder.dylibs[p], p)"
)


def python_for(spec: CoreSpec) -> str:
    if spec.name != "azahar":
        return sys.executable
    candidates = [os.environ.get("PV_PYTHON3", ""), HOMEBREW_BIN + "/python3", "python3", "python3.12", "python3.11", "python3.10"]
    for candidate in candidates:
        if not candidate:
            continue
        path = candidate if os.path.isabs(candidate) else shutil.which(candidate)
        if not path or not os.path.exists(path):
            continue
        check = subprocess.run([path, "-c", "import sys; print(sys.version_info >= (3, 10))"],
                               capture_output=True, text=True)
        if check.stdout.strip() == "True":
            return path
    raise SystemExit("build_slice: Azahar needs python3 >= 3.10 (brew install python@3.12, or set PV_PYTHON3)")


def build_env() -> Dict[str, str]:
    env = dict(os.environ)
    env["PATH"] = HOMEBREW_BIN + os.pathsep + env.get("PATH", "")
    return env


def run_wrapped_build(spec: CoreSpec, slice_name: str) -> None:
    snippet = AZAHAR_BUILD if spec.name == "azahar" else DOLPHIN_BUILD
    subprocess.run([python_for(spec), "-c", snippet, str(spec.script.parent), SLICES[slice_name]["cmake"]],
                   check=True, env=build_env(), cwd=str(spec.script.parent))


def pack_xcframework(spec: CoreSpec) -> None:
    log(f"{spec.name}: packing {spec.product}.xcframework from the slices present")
    if spec.name == "azahar":
        cmd = [python_for(spec), "-c", AZAHAR_XCFRAMEWORK, str(spec.script.parent)]
    else:
        cmd = [sys.executable, str(spec.script), "-x"]
    subprocess.run(cmd, check=True, env=build_env(), cwd=str(spec.script.parent))


def main(argv: Optional[List[str]] = None, runner: Runner = default_runner,
         env: Optional[Mapping[str, str]] = None, builder: Builder = run_wrapped_build) -> int:
    parser = argparse.ArgumentParser(description="Build or link one cached Azahar/Dolphin core slice.")
    parser.add_argument("core", choices=["azahar", "dolphin"])
    parser.add_argument("slice", choices=sorted(SLICES))
    parser.add_argument("--print-key", action="store_true", help="print the cache key and exit")
    parser.add_argument("--force", action="store_true", help="rebuild even on a cache hit")
    parser.add_argument("--cache-dir", type=Path, help="cache root (default $PV_CORE_CACHE or ~/Library/Caches/Provenance/cores)")
    parser.add_argument("--xcframework", action="store_true", help="also repack <Product>.xcframework (distribution)")
    parser.add_argument("--strict", action="store_true",
                        help="always scan the working trees for uncommitted edits (also PV_CORE_STRICT=1)")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    environment = dict(os.environ) if env is None else dict(env)
    spec = core_specs(args.repo_root.resolve())[args.core]
    label = f"{spec.name} {args.slice}"
    if args.print_key:
        print(compute_key(spec, args.slice, runner, environment))
        return 0

    cache = args.cache_dir or Path(environment.get("PV_CORE_CACHE") or DEFAULT_CACHE)
    cache = cache.expanduser()
    strict = args.strict or args.force or environment.get("PV_CORE_STRICT") == "1"
    record_path = prepared_record_path(spec, args.slice, cache)
    record = read_prepared(record_path)

    started = time.monotonic()
    log(f"{label}: checking whether the native library is up to date")
    fast = fast_fingerprint(spec, args.slice, runner, environment)
    key = record.get("key", "")
    if strict or record.get("fast") != fast or not key or not is_cached(spec, args.slice, cache, key):
        reason = "--strict" if strict else ("first preparation of this checkout" if not record else "inputs changed")
        log(f"{label}: scanning the {spec.name} source trees for uncommitted edits ({reason}); "
            "this can take minutes on a cold disk")
        inputs = key_inputs(spec, args.slice, runner, environment)
        key = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
        log(f"{label}: key {key[:12]} ({time.monotonic() - started:.0f}s)")
    else:
        inputs = {}
        log(f"{label}: unchanged since this checkout last prepared it; key {key[:12]} "
            f"({time.monotonic() - started:.1f}s; --strict rescans for uncommitted engine edits)")

    produced = args.force or not is_cached(spec, args.slice, cache, key)
    if produced:
        log(f"{label}: building {spec.product}; a cold build takes 30-60 minutes. Build output follows.")
    framework = ensure_slice(spec, args.slice, cache, key, inputs, args.force, builder)
    prepare_headers(spec, framework)
    packed = record.get("xcframework") == key and xcframework_has_slice(spec, args.slice)
    if needs_xcframework(spec, args.slice, produced, args.xcframework) and not (packed and not produced):
        pack_xcframework(spec)
        packed = True
    elif packed:
        log(f"{label}: {spec.product}.xcframework already holds this slice")
    write_prepared(record_path, {"fast": fast, "key": key, **({"xcframework": key} if packed else {})})
    log(f"{label}: ready ({time.monotonic() - started:.0f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
