#!/usr/bin/env python3
"""Fetch, unpack and index the slang shader library bundled with Provenance.

The library is the libretro slang preset collection compiled to Metal by the
OpenEmu-Shaders `oeshaders` tool (github.com/JoeMatt/slang-shaders-metal),
pinned by `slang-shaders.lock.json`, plus the hand-written presets committed
under `PVShaders/Library/`.

Each `.oecompiledshader` archive is unpacked into a directory holding
`shader.json` and its LUT images, so the app never unzips at runtime. The
script then writes `manifest.json`, the index the app's shader browser reads.

The result is cached per lock + extras content in
`$PV_SLANG_CACHE` or `~/Library/Caches/Provenance/slang-shaders/<key12>/`.

Usage:
    fetch_slang_shaders.py                 # build the cache, print its path
    fetch_slang_shaders.py --out DIR       # also mirror the library into DIR
    fetch_slang_shaders.py --print-key     # print the cache key (CI cache key)
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LOCK_FILE = Path(__file__).resolve().parent / "slang-shaders.lock.json"
EXCLUDED_FILE = Path(__file__).resolve().parent / "slang-shaders-excluded.json"
EXTRAS_DIR = REPO_ROOT / "PVShaders" / "Library"
# Bump when the unpack or manifest format changes, so caches rebuild.
FORMAT_VERSION = 1
MANIFEST_NAME = "manifest.json"
ARCHIVE_SUFFIX = ".oecompiledshader"
# LUT members are named "<lutname>__<original file name>".
LUT_MEMBER = re.compile(r"^[A-Za-z0-9_.\-]+__[A-Za-z0-9_. \-()+]+$")
COMPUTE_KERNEL = re.compile(r"\bkernel\s+void\b")


class FetchError(Exception):
    pass


def load_lock() -> dict:
    lock = json.loads(LOCK_FILE.read_text())
    for key in ("repo", "tag", "asset", "sha256"):
        if not lock.get(key):
            raise FetchError(f"{LOCK_FILE.name}: missing '{key}'")
    return lock


def extras_digest() -> str:
    """Hash of every committed extra preset, so editing one rebuilds the cache."""
    digest = hashlib.sha256()
    if EXTRAS_DIR.is_dir():
        for path in sorted(EXTRAS_DIR.rglob("*")):
            if path.is_file() and not path.name.startswith("."):
                digest.update(str(path.relative_to(EXTRAS_DIR)).encode())
                digest.update(path.read_bytes())
    return digest.hexdigest()


def cache_key(lock: dict) -> str:
    digest = hashlib.sha256()
    digest.update(f"format={FORMAT_VERSION}\n".encode())
    digest.update(f"asset={lock['sha256']}\n".encode())
    digest.update(f"extras={extras_digest()}\n".encode())
    if EXCLUDED_FILE.exists():
        digest.update(EXCLUDED_FILE.read_bytes())
    return digest.hexdigest()


def cache_root() -> Path:
    override = os.environ.get("PV_SLANG_CACHE")
    if override:
        return Path(override)
    return Path.home() / "Library" / "Caches" / "Provenance" / "slang-shaders"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(lock: dict, dest: Path) -> None:
    """Download the pinned release asset into `dest`, verifying its sha256."""
    if dest.exists() and sha256_file(dest) == lock["sha256"]:
        return
    url = f"https://github.com/{lock['repo']}/releases/download/{lock['tag']}/{lock['asset']}"
    print(f"Downloading {url}", file=sys.stderr)
    dest.parent.mkdir(parents=True, exist_ok=True)
    partial = dest.with_suffix(".part")
    with urllib.request.urlopen(url, timeout=120) as response, partial.open("wb") as out:
        shutil.copyfileobj(response, out)
    actual = sha256_file(partial)
    if actual != lock["sha256"]:
        partial.unlink()
        raise FetchError(f"sha256 mismatch for {url}: expected {lock['sha256']}, got {actual}")
    partial.replace(dest)


def is_symlink(info: zipfile.ZipInfo) -> bool:
    return stat.S_ISLNK(info.external_attr >> 16)


def safe_relative(name: str) -> Path | None:
    """Return `name` as a relative path, or None if it escapes or is junk."""
    if not name or name.startswith("/") or "\\" in name:
        return None
    parts = Path(name).parts
    if any(part in ("..", "") for part in parts):
        return None
    if parts[0] == "__MACOSX" or any(part.startswith("._") for part in parts):
        return None
    return Path(*parts)


def unpack_preset(data: bytes, dest: Path) -> None:
    """Unpack one `.oecompiledshader` archive into `dest` (flat: shader.json + LUTs)."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members = [info for info in archive.infolist() if not info.is_dir()]
        names = set()
        for info in members:
            if is_symlink(info):
                raise FetchError("symlink in archive")
            relative = safe_relative(info.filename)
            if relative is None:
                if info.filename.startswith("__MACOSX") or Path(info.filename).name.startswith("._"):
                    continue
                raise FetchError(f"unsafe member path {info.filename!r}")
            # Presets are flat; nested entries are tolerated by keeping only the leaf.
            leaf = relative.name
            if leaf != "shader.json" and not LUT_MEMBER.match(leaf):
                raise FetchError(f"unexpected member {info.filename!r}")
            if leaf in names:
                raise FetchError(f"duplicate member {leaf!r}")
            names.add(leaf)
        if "shader.json" not in names:
            raise FetchError("missing shader.json")
        dest.mkdir(parents=True, exist_ok=True)
        for info in members:
            relative = safe_relative(info.filename)
            if relative is None:
                continue
            (dest / relative.name).write_bytes(archive.read(info))


def unpack_library(zip_path: Path, library: Path) -> list[str]:
    """Unpack every preset in the release zip into `library`. Returns failures."""
    failures = []
    with zipfile.ZipFile(zip_path) as release:
        for info in release.infolist():
            if info.is_dir() or not info.filename.endswith(ARCHIVE_SUFFIX):
                continue
            relative = safe_relative(info.filename)
            if relative is None:
                continue
            # Drop the release's top-level "compiled_shaders/" folder.
            parts = relative.parts[1:] if relative.parts[0] == "compiled_shaders" else relative.parts
            preset_id = str(Path(*parts))[: -len(ARCHIVE_SUFFIX)]
            try:
                unpack_preset(release.read(info), library / preset_id)
            except (FetchError, zipfile.BadZipFile) as error:
                failures.append(f"{preset_id}: {error}")
                shutil.rmtree(library / preset_id, ignore_errors=True)
    return failures


def copy_extras(library: Path) -> None:
    if not EXTRAS_DIR.is_dir():
        return
    for shader_json in sorted(EXTRAS_DIR.rglob("shader.json")):
        source = shader_json.parent
        dest = library / source.relative_to(EXTRAS_DIR)
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(source, dest, ignore=shutil.ignore_patterns(".*"))


def display_name(preset_id: str) -> str:
    leaf = preset_id.rsplit("/", 1)[-1]
    return leaf.replace("_", " ").replace("-", " ").strip()


def manifest_entry(preset_id: str, shader: dict, excluded: dict) -> dict:
    passes = shader.get("passes", [])
    sources = "\n".join(p.get("vertexSource", "") + p.get("fragmentSource", "") for p in passes)
    reason = excluded.get(preset_id)
    if reason is None and COMPUTE_KERNEL.search(sources):
        reason = "uses compute kernels"
    if reason is None and not passes:
        reason = "no passes"
    entry = {
        "id": preset_id,
        "name": display_name(preset_id),
        "category": preset_id.split("/", 1)[0] if "/" in preset_id else "",
        "passes": len(passes),
        "history": shader.get("historyCount", 0),
        "feedback": any(p.get("isFeedback") for p in passes),
        "luts": len(shader.get("luts", [])),
        "parameters": [
            {
                "name": p["name"],
                "label": p.get("desc") or p["name"],
                "initial": p["initial"],
                "minimum": p["minimum"],
                "maximum": p["maximum"],
                "step": p["step"],
            }
            for p in shader.get("parameters", [])
        ],
    }
    if reason:
        entry["excluded"] = reason
    return entry


def build_manifest(library: Path, lock: dict) -> dict:
    excluded = json.loads(EXCLUDED_FILE.read_text()) if EXCLUDED_FILE.exists() else {}
    entries = []
    for shader_json in sorted(library.rglob("shader.json")):
        preset_id = str(shader_json.parent.relative_to(library))
        try:
            shader = json.loads(shader_json.read_text())
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            entries.append({"id": preset_id, "name": display_name(preset_id),
                            "category": preset_id.split("/", 1)[0], "passes": 0, "history": 0,
                            "feedback": False, "luts": 0, "parameters": [],
                            "excluded": f"invalid shader.json: {error}"})
            continue
        entries.append(manifest_entry(preset_id, shader, excluded))
    return {
        "formatVersion": FORMAT_VERSION,
        "source": {"repo": lock["repo"], "tag": lock["tag"], "sha256": lock["sha256"]},
        "presets": entries,
    }


def build_cache(lock: dict) -> Path:
    key = cache_key(lock)
    root = cache_root() / key[:12]
    library = root / "library"
    if (library / MANIFEST_NAME).exists():
        return library

    archive = cache_root() / "downloads" / f"{lock['sha256'][:12]}-{lock['asset']}"
    download(lock, archive)
    staging = Path(tempfile.mkdtemp(prefix="library-", dir=cache_root()))
    try:
        failures = unpack_library(archive, staging)
        for failure in failures:
            print(f"warning: skipped {failure}", file=sys.stderr)
        copy_extras(staging)
        manifest = build_manifest(staging, lock)
        (staging / MANIFEST_NAME).write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
        shutil.copy(REPO_ROOT / "PVShaders" / "SLANG_SHADERS_NOTICE.md", staging / "NOTICE.md")
        root.mkdir(parents=True, exist_ok=True)
        if library.exists():
            shutil.rmtree(library)
        staging.replace(library)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    usable = sum(1 for p in manifest["presets"] if "excluded" not in p)
    print(f"Slang library: {usable} usable presets ({len(manifest['presets'])} total) in {library}",
          file=sys.stderr)
    return library


def mirror(library: Path, out: Path) -> None:
    """Make `out` an exact copy of `library` (deletes extra files in `out`)."""
    out.mkdir(parents=True, exist_ok=True)
    wanted = {p.relative_to(library) for p in library.rglob("*")}
    for existing in sorted(out.rglob("*"), reverse=True):
        if existing.relative_to(out) not in wanted:
            if existing.is_dir() and not existing.is_symlink():
                shutil.rmtree(existing)
            else:
                existing.unlink()
    for source in sorted(library.rglob("*")):
        dest = out / source.relative_to(library)
        if source.is_dir():
            dest.mkdir(parents=True, exist_ok=True)
        elif not dest.exists() or dest.stat().st_size != source.stat().st_size \
                or dest.stat().st_mtime < source.stat().st_mtime:
            shutil.copy2(source, dest)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, help="mirror the unpacked library into this directory")
    parser.add_argument("--print-key", action="store_true", help="print the cache key and exit")
    args = parser.parse_args(argv)
    try:
        lock = load_lock()
        if args.print_key:
            print(cache_key(lock))
            return 0
        library = build_cache(lock)
        if args.out:
            mirror(library, args.out)
        print(library)
    except (FetchError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
