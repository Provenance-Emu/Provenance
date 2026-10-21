#!/usr/bin/env python3
"""Build ABI-matched legacy emuThree vendor libraries for arm64 Apple platforms."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PINS = {
    "openal": ("https://github.com/kcat/openal-soft.git", "d3875f333fb6abe2f39d82caca329414871ae53b"),
    "dynarmic": ("https://github.com/azahar-emu/dynarmic.git", "a179e2f2bb74e386c353ee2f6af3302e75075c3c"),
    "enet": ("https://github.com/lsalzman/enet.git", "4f8e9bdc4ce6d1f61a6274b0e557065a38190952"),
    "fmt": ("https://github.com/fmtlib/fmt.git", "c4ee726532178e556d923372f29163bd206d7732"),
    "glslang": ("https://github.com/KhronosGroup/glslang.git", "c0cf8ad87627227c7f1d3be6177bbf2832d3fc1b"),
    "sirit": ("https://github.com/GPUCode/sirit.git", "f0b6bbe55b3714f23476634b0105ad246f0819e2"),
    "sirit/externals/SPIRV-Headers": ("https://github.com/KhronosGroup/SPIRV-Headers.git", "a3fdfe81465d57efc97cfd28ac6c8190fb31a6c8"),
    "teakra": ("https://github.com/wwylele/teakra.git", "01db7cdd00aabcce559a8dddce8798dabb71949b"),
}
TARGETS = ["GenericCodeGen", "HLSL", "MachineIndependent", "OGLCompiler", "OSDependent", "SPIRV", "SoundTouch",
           "boost_iostreams", "boost_program_options", "boost_serialization", "dynarmic", "enet", "fmt", "glslang", "mcl", "sirit", "teakra", "libzstd_static", "OpenAL"]


def run(*args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def prepare_sources(work, local):
    sources = work / "sources"
    for name, (url, revision) in PINS.items():
        destination = sources / name
        stamp = work / "stamps" / (name.replace("/", "-") + ".json")
        if stamp.exists() and json.loads(stamp.read_text())["revision"] == revision and (destination / "CMakeLists.txt").exists():
            continue
        cached = local / name if local and (local / name).is_dir() else None
        cache = cached if cached else work / "git" / name
        if cached is None:
            if not (cache / ".git").exists():
                cache.mkdir(parents=True, exist_ok=True)
                run("git", "init", cache)
            run("git", "-C", cache, "fetch", "--depth", "1", url, revision)
        if destination.exists():
            shutil.rmtree(destination)
        destination.mkdir(parents=True, exist_ok=True)
        # Export the pinned object, never the possibly dirty local checkout.
        archive = work / "export.tar"
        run("git", "-C", cache, "archive", "--format=tar", "-o", archive, revision)
        with tarfile.open(archive) as bundle:
            bundle.extractall(destination, filter="data")
        stamp.parent.mkdir(parents=True, exist_ok=True)
        stamp.write_text(json.dumps({"revision": revision, "url": url}))
    boost = sources / "boost"
    boost_stamp = work / "stamps/boost-1.81.0"
    if not boost_stamp.exists():
        archive = work / "boost_1_81_0.tar.bz2"
        if not archive.exists():
            urllib.request.urlretrieve("https://archives.boost.io/release/1.81.0/source/boost_1_81_0.tar.bz2", archive)
        expected = "71feeed900fbccca04a3b4f2f84a7c217186f28a940ed8b7ed4725986baf99fa"
        if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
            raise RuntimeError("Boost source checksum mismatch")
        prefixes = ["boost_1_81_0/boost/"] + [f"boost_1_81_0/libs/{name}/src/" for name in ["iostreams", "program_options", "serialization"]]
        with tarfile.open(archive) as bundle:
            members = [m for m in bundle.getmembers() if any(m.name.startswith(prefix) for prefix in prefixes)]
            bundle.extractall(sources, members=members, filter="data")
        if boost.exists():
            shutil.rmtree(boost)
        (sources / "boost_1_81_0").rename(boost)
        boost_stamp.touch()
    soundtouch = sources / "soundtouch"
    if not soundtouch.exists():
        archive = work / "soundtouch-1.8.0.tar.gz"
        if not archive.exists():
            urllib.request.urlretrieve("https://www.surina.net/soundtouch/soundtouch-1.8.0.tar.gz", archive)
        expected = "3d4161d74ca25c5a98c69dbb8ea10fd2be409ba1a3a0bf81db407c4c261f166b"
        if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
            raise RuntimeError("SoundTouch source checksum mismatch")
        with tarfile.open(archive) as bundle:
            bundle.extractall(sources, filter="data")
        if not soundtouch.exists():
            (sources / "soundtouch-1.8.0").rename(soundtouch)
    return sources


def verify_headers(sources):
    headers = ROOT / "Cores/emuThree/emuthree/emuThreeDS/externals/include"
    pairs = [(f"dynarmic/interface/A32/{name}", f"dynarmic/src/dynarmic/interface/A32/{name}")
             for name in ["a32.h", "config.h", "context.h", "coprocessor.h"]]
    pairs += [("glslang/Public/ShaderLang.h", "glslang/glslang/Public/ShaderLang.h"),
              ("fmt/core.h", "fmt/include/fmt/core.h"),
              ("SoundTouch/SoundTouch.h", "soundtouch/include/SoundTouch.h"),
              ("sirit/sirit.h", "sirit/include/sirit/sirit.h"),
              ("boost/version.hpp", "boost/boost/version.hpp")]

    def api(path):
        text = path.read_text().replace("<sirit/spirv/", "<spirv/")
        text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
        return " ".join(text.split())

    for engine_header, source_header in pairs:
        if api(headers / engine_header) != api(sources / source_header):
            raise RuntimeError(f"Vendor public header mismatch: {engine_header}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-cache", type=Path, help="Optional existing Citra externals Git cache; files are exported at pinned revisions")
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    work = ROOT / "build/emuthree-vendors"
    work.mkdir(parents=True, exist_ok=True)
    sources = prepare_sources(work, args.source_cache)
    verify_headers(sources)
    for sdk, platform in [("iphonesimulator", "iOS"), ("appletvsimulator", "tvOS"), ("appletvos", "tvOS")]:
        build = work / sdk
        sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
        run("cmake", "-S", ROOT / "Scripts/cores/emuthree-vendors", "-B", build, "-G", "Ninja",
            f"-DPV_SOURCES={sources}", f"-DPV_REPO={ROOT}", "-DCMAKE_BUILD_TYPE=Release",
            f"-DCMAKE_SYSTEM_NAME={platform}", f"-DCMAKE_OSX_SYSROOT={sdk_path}", "-DCMAKE_OSX_ARCHITECTURES=arm64",
            "-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0", "-DCMAKE_SYSTEM_PROCESSOR=arm64", "-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
        run("cmake", "--build", build, "--parallel", args.jobs, "--target", *TARGETS)
        libraries = []
        for target in TARGETS:
            name = {"libzstd_static": "libzstd.a", "OpenAL": "libopenal.a"}.get(target, f"lib{target}.a")
            matches = list(build.rglob(name))
            if len(matches) != 1:
                raise RuntimeError(f"Expected one {name}, got {matches}")
            libraries.append(matches[0])
        libraries += [p for p in (build / "openal").rglob("*.a") if p not in libraries]
        run("xcrun", "libtool", "-static", "-o", build / "libPVEmuThreeVendors.a", *libraries)
    device = work / "iphoneos"
    device.mkdir(exist_ok=True)
    original = list((ROOT / "Cores/emuThree/lib").glob("*EmuThree.a")) + [ROOT / "Dependencies/libopenal.xcframework/ios-arm64/libopenal.a"]
    thin = []
    for library in original:
        destination = device / library.name
        architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(library)], text=True).split()
        if architectures == ["arm64"]:
            shutil.copy2(library, destination)
        else:
            run("xcrun", "lipo", library, "-thin", "arm64", "-output", destination)
        thin.append(destination)
    run("xcrun", "libtool", "-static", "-o", device / "libPVEmuThreeVendors.a", *thin)
    bundle = work / "PVEmuThreeVendors.xcframework"
    if bundle.exists():
        shutil.rmtree(bundle)
    arguments = []
    for sdk in ["iphoneos", "iphonesimulator", "appletvos", "appletvsimulator"]:
        arguments += ["-library", work / sdk / "libPVEmuThreeVendors.a",
                      "-headers", ROOT / "Dependencies/libopenal.xcframework/ios-arm64/Headers"]
    run("xcodebuild", "-create-xcframework", *arguments, "-output", bundle)
    output = ROOT / "Cores/emuThree/SwiftPM/Vendors/PVEmuThreeVendors.xcframework"
    if output.exists():
        shutil.rmtree(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(bundle, output)
    license_output = output.parent / "Licenses"
    license_output.mkdir(exist_ok=True)
    licenses = {"dynarmic": "dynarmic/LICENSE.txt", "mcl": "dynarmic/externals/mcl/LICENSE",
                "oaknut": "dynarmic/externals/oaknut/LICENSE", "robin-map": "dynarmic/externals/robin-map/LICENSE",
                "fmt": "fmt/LICENSE.rst", "glslang": "glslang/LICENSE.txt", "sirit": "sirit/LICENSE.txt",
                "SPIRV-Headers": "sirit/externals/SPIRV-Headers/LICENSE", "enet": "enet/LICENSE",
                "teakra": "teakra/LICENSE", "SoundTouch": "soundtouch/COPYING.TXT", "OpenAL-Soft": "openal/COPYING"}
    for name, relative in licenses.items():
        shutil.copy2(sources / relative, license_output / (name + ".txt"))
    with tarfile.open(work / "boost_1_81_0.tar.bz2") as archive:
        (license_output / "Boost.txt").write_bytes(archive.extractfile("boost_1_81_0/LICENSE_1_0.txt").read())
    shutil.copy2(ROOT / "Cores/emuThree/cmake/zstd/LICENSE", license_output / "Zstandard.txt")
    for license_file in license_output.glob("*.txt"):
        license_file.write_text("\n".join(line.rstrip() for line in license_file.read_text().splitlines()) + "\n")
    metadata = {"pins": PINS, "boost": {"version": "1.81.0", "sha256": "71feeed900fbccca04a3b4f2f84a7c217186f28a940ed8b7ed4725986baf99fa"},
                "soundtouch": {"version": "1.8.0", "samples": "signed 16-bit PCM", "sha256": "3d4161d74ca25c5a98c69dbb8ea10fd2be409ba1a3a0bf81db407c4c261f166b"},
                "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
                "ios_device_inputs": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(original)},
                "slices": {p.parent.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.glob("*/*.a"))}}
    (output.parent / "BuildInfo.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
