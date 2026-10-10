#!/usr/bin/env python3
"""Build one Azahar or Dolphin core slice outside the app, cached by a content key.

  build_slice.py <azahar|dolphin> <ios|ios-sim|tvos|tvos-sim> [--print-key] [--force]
                 [--cache-dir DIR] [--xcframework]

Key: sha256 over the core submodule HEAD and `git submodule status --recursive` inside it,
the wrapped build script and CMake toolchain contents (Azahar's CMAKE_OPTIONS live in its
script), Dolphin's DOL_FULL_LTO / DOL_PGO / DOL_PGO_PROFILE and the PGO profile it would use,
`xcodebuild -version`, the slice SDK version and, for Azahar, the MoltenVK static slice it
configures against. `--print-key` prints it (CI cache keys).

Cache: $PV_CORE_CACHE or ~/Library/Caches/Provenance/cores, laid out as
<core>/<slice>/<key[:12]>/<Product>-<slice>.framework + stamp.json. On a hit the legacy output
path (Cores/Azahar/build/xcframework/PVlibAzahar-<slice>.framework,
Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin-<slice>.framework) becomes a symlink
into the cache, so PVAzahar's PVAZAHAR_ARCHIVE path and PVDolphin's references don't change.
On a miss the wrapped builder builds that one slice (its per-platform methods, not its main(),
which would also repack the xcframework), the product moves into the cache and is linked.
--xcframework repacks <Product>.xcframework for distribution; Dolphin also repacks it when it
is missing, since PVDolphin.xcodeproj links the xcframework at planning time.

Python 3.9 compatible (Dolphin's Xcode phase runs /usr/bin/python3). Azahar's builder needs
3.10+, so it runs in a separate interpreter (PV_PYTHON3, Homebrew python3, python3.1x).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
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
        ),
    }


def log(message: str) -> None:
    print(f"build_slice: {message}", file=sys.stderr, flush=True)


def default_runner(cmd: List[str], cwd: Optional[Path] = None) -> str:
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=True, capture_output=True, text=True)
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


def dolphin_profile(spec: CoreSpec, env: Mapping[str, str]) -> Optional[Path]:
    """The profile BuildiOSXCFramework.resolve_pgo would use (None for off/generate)."""
    mode = env.get("DOL_PGO", "").strip().lower()
    if mode in ("off", "generate"):
        return None
    explicit = env.get("DOL_PGO_PROFILE", "").strip()
    if explicit:
        return Path(explicit)
    default = spec.submodule / "pgo" / "icube.profdata"
    return default if default.exists() else None


def key_inputs(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> Dict[str, str]:
    sl = SLICES[slice_name]
    inputs = {
        "core": spec.name,
        "slice": slice_name,
        "submodule_head": runner(["git", "-C", str(spec.submodule), "rev-parse", "HEAD"], None),
        "submodule_tree": normalize_submodule_status(
            runner(["git", "-C", str(spec.submodule), "submodule", "status", "--recursive"], None)),
        "script": file_hash(spec.script),
        "toolchain": file_hash(spec.toolchain),
        "xcode": runner(["xcodebuild", "-version"], None),
        "sdk": runner(["xcrun", "--sdk", sl["sdk"], "--show-sdk-version"], None),
    }
    for name in spec.env_flags:
        if name not in ("DOL_PGO", "DOL_PGO_PROFILE"):
            inputs["env:" + name] = env.get(name, "")
    if spec.name == "dolphin":
        # Only the effective PGO state matters: "off" and "no profile" build the same binary.
        inputs["pgo_generate"] = "1" if env.get("DOL_PGO", "").strip().lower() == "generate" else ""
        profile = dolphin_profile(spec, env)
        inputs["pgo_profile"] = file_hash(profile) if profile is not None and profile.exists() else ""
    if spec.moltenvk is not None:
        inputs["moltenvk"] = file_hash(spec.moltenvk / sl["mvk"] / "libMoltenVK.a")
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


def prune_entries(slice_dir: Path, keep: int, current: Path) -> None:
    entries = [p for p in slice_dir.iterdir() if p.is_dir() and p != current]
    entries.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    for stale in entries[max(0, keep - 1):]:
        log(f"pruning old cache entry {stale}")
        shutil.rmtree(stale)


def ensure_slice(spec: CoreSpec, slice_name: str, cache: Path, key: str, inputs: Mapping[str, str],
                 force: bool, builder: Builder) -> Path:
    entry = cache / spec.name / slice_name / key[:12]
    framework = entry / framework_name(spec, slice_name)
    stamp = entry / "stamp.json"
    if not force and framework.is_dir() and stamp.is_file():
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
        "built": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
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
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    environment = dict(os.environ) if env is None else dict(env)
    spec = core_specs(args.repo_root.resolve())[args.core]
    inputs = key_inputs(spec, args.slice, runner, environment)
    key = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    if args.print_key:
        print(key)
        return 0

    cache = args.cache_dir or Path(environment.get("PV_CORE_CACHE") or DEFAULT_CACHE)
    ensure_slice(spec, args.slice, cache.expanduser(), key, inputs, args.force, builder)
    xcframework = spec.legacy_dir / f"{spec.product}.xcframework"
    if args.xcframework or (spec.name == "dolphin" and not xcframework.exists()):
        pack_xcframework(spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
