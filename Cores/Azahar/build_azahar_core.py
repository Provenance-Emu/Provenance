#!/usr/bin/env python3
"""
Build the azahar 3DS emulator libraries for iOS/tvOS and package them as
PVlibAzahar.xcframework for Cores/Azahar/PVAzahar.xcodeproj.

Source: Cores/Azahar/azahar (Provenance-Emu/azahar, branch `provenance`; see PATCHES.md)
Output: Cores/Azahar/build/xcframework/PVlibAzahar-<slice>.framework/{PVlibAzahar, Headers/}
        per platform (PVlibAzahar = every built static archive merged with libtool), then
        Cores/Azahar/build/xcframework/PVlibAzahar.xcframework, a library xcframework
        (<slice>/libPVlibAzahar.a + Headers/) combining every slice present.

MoltenVK is linked from the repo's static xcframework at
MoltenVK/MoltenVK/static/MoltenVK.xcframework/<slice>/libMoltenVK.a
(USE_SYSTEM_MOLTENVK=ON, so azahar never downloads its own copy). It is passed to
CMake only to satisfy configure; it is not merged into PVlibAzahar.

Submodules of the azahar checkout needed besides the externals: dist/compatibility_list
(CMakeLists.txt configure_file()s its .qrc unconditionally).

Usage:
  build_azahar_core.py -p OS64            # one slice (iphoneos)
  build_azahar_core.py --all-platforms    # all four slices + xcframework
  build_azahar_core.py --clean -p TVOS
"""

import argparse
import multiprocessing
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "azahar"
BUILD = ROOT / "build"
XCFRAMEWORK_DIR = BUILD / "xcframework"
TOOLCHAIN = ROOT / "cmake" / "ios.toolchain.cmake"
LIB_NAME = "PVlibAzahar"
BUNDLE_ID = f"org.provenance-emu.{LIB_NAME}"
MOLTENVK_XCFW = ROOT.parents[1] / "MoltenVK" / "MoltenVK" / "static" / "MoltenVK.xcframework"

PLATFORMS = {
    "OS64":           {"sdk": "iphoneos",          "slice": "ios",      "min": "17.0", "mvk": "ios-arm64"},
    "SIMULATORARM64": {"sdk": "iphonesimulator",   "slice": "ios-sim",  "min": "17.0", "mvk": "ios-arm64_x86_64-simulator"},
    "TVOS":           {"sdk": "appletvos",         "slice": "tvos",     "min": "17.0", "mvk": "tvos-arm64_arm64e"},
    "SIMULATOR_TVOS": {"sdk": "appletvsimulator",  "slice": "tvos-sim", "min": "17.0", "mvk": "tvos-arm64_x86_64-simulator"},
}

# CFBundleSupportedPlatforms value for each SDK.
SUPPORTED_PLATFORM = {
    "iphoneos": "iPhoneOS",
    "iphonesimulator": "iPhoneSimulator",
    "appletvos": "AppleTVOS",
    "appletvsimulator": "AppleTVSimulator",
}

CMAKE_OPTIONS = [
    "-DCMAKE_BUILD_TYPE=Release",
    "-DENABLE_QT=OFF", "-DENABLE_SDL2=OFF", "-DENABLE_WEB_SERVICE=OFF",
    "-DENABLE_SCRIPTING=OFF", "-DENABLE_GDBSTUB=OFF", "-DENABLE_OPENAL=OFF",
    "-DENABLE_CUBEB=OFF", "-DENABLE_LIBUSB=OFF", "-DENABLE_FFMPEG=OFF",
    "-DENABLE_COREAUDIO=ON", "-DENABLE_SOFTWARE_RENDERER=OFF", "-DENABLE_VULKAN=ON",
    "-DENABLE_TESTS=OFF", "-DENABLE_ROOM=OFF", "-DENABLE_DISCORD_RPC=OFF",
    # LTO off: with it every object is LLVM bitcode, which `xcodebuild -create-xcframework`
    # rejects ("unable to find any architecture information") and which only links with
    # the exact clang that produced it.
    "-DENABLE_LTO=OFF", "-DUSE_SYSTEM_MOLTENVK=ON",
    "-DCITRA_WARNINGS_AS_ERRORS=OFF", "-DENABLE_COMPATIBILITY_LIST_DOWNLOAD=OFF",
    # libressl's option. The ios toolchain reports CMAKE_C_COMPILER_ABI=ELF, so libressl
    # picks its 32-bit ELF armv4 assembly, which cannot assemble for arm64 Mach-O.
    "-DENABLE_ASM=OFF",
]

# CMake targets whose static archives make up PVlibAzahar. Externals are pulled in
# transitively by `ninja <targets>`; we then harvest every .a under the build dir.
TARGETS = ["citra_core", "citra_common", "video_core", "audio_core", "network", "input_common"]

HEADER_EXTS = (".h", ".hpp", ".inc", ".inl")


class BuildError(Exception):
    """A build step failed."""


def log(message: str, level: str = "info") -> None:
    prefix = {"info": "ℹ️", "success": "✅", "error": "❌", "build": "🔨", "package": "📦", "debug": "🔍"}
    stream = sys.stderr if level == "error" else sys.stdout
    print(f"{prefix.get(level, 'ℹ️')} {message}", file=stream, flush=True)


def run(cmd: list[str], cwd: Path | None = None, verbose: bool = False) -> None:
    if verbose:
        log(f"Running: {' '.join(cmd)}" + (f"  (in {cwd})" if cwd else ""), "debug")
    try:
        subprocess.check_call(cmd, cwd=cwd)
    except subprocess.CalledProcessError as e:
        raise BuildError(f"`{cmd[0]}` exited with {e.returncode}") from e


class AzaharBuilder:
    """Builds the azahar static libraries per platform and packages the xcframework."""

    def __init__(self, verbose: bool = False, clean: bool = False):
        self.verbose = verbose
        self.clean = clean
        for tool in ("cmake", "ninja", "libtool", "xcodebuild"):
            if not shutil.which(tool):
                raise BuildError(f"{tool} not found in PATH")
        if not (SRC / "CMakeLists.txt").exists():
            raise BuildError(f"azahar source missing at {SRC}; run `git submodule update --init Cores/Azahar/azahar`")

    def build_platform(self, platform: str) -> Path:
        """Configure, build, and package one platform; returns its .framework path."""
        out = BUILD / platform
        if self.clean and out.exists():
            log(f"Cleaning {out}", "info")
            shutil.rmtree(out)
        self.configure(platform, out)
        log(f"Building {platform} ({', '.join(TARGETS)})", "build")
        run(["ninja", f"-j{multiprocessing.cpu_count()}", *TARGETS], cwd=out, verbose=self.verbose)
        libs = self.harvest(out)
        log(f"Merging {len(libs)} static archives for {platform}", "package")
        return self.merge(platform, out, libs)

    def configure(self, platform: str, out: Path) -> None:
        p = PLATFORMS[platform]
        out.mkdir(parents=True, exist_ok=True)
        mvk = MOLTENVK_XCFW / p["mvk"] / "libMoltenVK.a"
        if not mvk.exists():
            raise BuildError(f"MoltenVK static slice missing: {mvk}")
        cmd = ["cmake", str(SRC), "-GNinja",
               f"-DCMAKE_TOOLCHAIN_FILE={TOOLCHAIN}", f"-DPLATFORM={platform}",
               f"-DDEPLOYMENT_TARGET={p['min']}", "-DENABLE_BITCODE=OFF", "-DENABLE_ARC=OFF",
               "-DENABLE_VISIBILITY=OFF",
               # Without strict checks every check_function_exists() passes (try_compile only
               # builds a static lib), and libressl then uses syslog_r/explicit_bzero/getauxval.
               "-DENABLE_STRICT_TRY_COMPILE=ON",
               f"-DMOLTENVK_LIBRARY={mvk}",
               *CMAKE_OPTIONS]
        if shutil.which("ccache"):
            cmd += ["-DCMAKE_C_COMPILER_LAUNCHER=ccache", "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"]
        log(f"Configuring {platform}", "build")
        run(cmd, cwd=out, verbose=self.verbose)

    @staticmethod
    def harvest(out: Path) -> list[Path]:
        libs = sorted(set(out.rglob("*.a")))
        # Exclude anything we never link (tests), MoltenVK itself (linked by the app), and
        # CMake's own probe archives under CMakeFiles/ (e.g. _CMakeLTOTest-*/bin/libfoo.a).
        return [lib for lib in libs
                if "CMakeFiles" not in lib.relative_to(out).parts
                and not any(s in lib.name for s in ("MoltenVK", "catch2", "Catch2"))]

    def merge(self, platform: str, out: Path, libs: list[Path]) -> Path:
        p = PLATFORMS[platform]
        fw = XCFRAMEWORK_DIR / f"{LIB_NAME}-{p['slice']}.framework"
        if fw.exists():
            shutil.rmtree(fw)
        (fw / "Headers").mkdir(parents=True)
        run(["libtool", "-static", "-no_warning_for_no_symbols", "-o", str(fw / LIB_NAME), *map(str, libs)],
            verbose=self.verbose)
        copy_headers(fw / "Headers", out)
        write_framework_plist(fw, p["sdk"], p["min"])
        log(f"Framework created at {fw}", "success")
        return fw

    def create_xcframework(self) -> Path:
        """Combine every PVlibAzahar-*.framework present (this run's and earlier ones).

        Slices go in as `-library <archive> -headers <Headers>`: `-framework` requires the
        binary to be named after the bundle directory (PVlibAzahar-ios), and a library
        xcframework puts Headers/ on the consumer's header search path, which azahar's
        own `#include "core/core.h"` style needs. `-library` insists on a `.a` name, so each
        archive is hard-linked to build/staging/<slice>/libPVlibAzahar.a first.
        """
        frameworks = sorted(XCFRAMEWORK_DIR.glob(f"{LIB_NAME}-*.framework"))
        if not frameworks:
            raise BuildError(f"no {LIB_NAME}-*.framework in {XCFRAMEWORK_DIR}")
        xcfw = XCFRAMEWORK_DIR / f"{LIB_NAME}.xcframework"
        if xcfw.exists():
            shutil.rmtree(xcfw)
        cmd = ["xcodebuild", "-create-xcframework", "-output", str(xcfw)]
        for fw in frameworks:
            staged = BUILD / "staging" / fw.stem / f"lib{LIB_NAME}.a"
            staged.parent.mkdir(parents=True, exist_ok=True)
            staged.unlink(missing_ok=True)
            staged.hardlink_to(fw / LIB_NAME)
            cmd += ["-library", str(staged), "-headers", str(fw / "Headers")]
        log(f"Creating {xcfw.name} from {len(frameworks)} framework(s)", "package")
        run(cmd, verbose=self.verbose)
        return xcfw


def copy_headers(dst: Path, out: Path) -> None:
    def cp_tree(src: Path, sub: str) -> None:
        for f in src.rglob("*"):
            if f.suffix in HEADER_EXTS and f.is_file():
                target = dst / sub / f.relative_to(src)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, target)

    ext = SRC / "externals"
    cp_tree(SRC / "src", "")  # core/, common/, video_core/, audio_core/, network/, input_common/
    cp_tree(ext / "boost" / "boost", "boost")
    cp_tree(ext / "fmt" / "include" / "fmt", "fmt")
    cp_tree(ext / "vulkan-headers" / "include" / "vulkan", "vulkan")
    cp_tree(ext / "vulkan-headers" / "include" / "vk_video", "vk_video")
    cp_tree(ext / "vma" / "include", "")
    cp_tree(ext / "nihstro" / "include" / "nihstro", "nihstro")
    cp_tree(ext / "dds-ktx", "")
    # Generated headers (scm_rev.h, host_shaders) live in the platform's build dir.
    cp_tree(out / "src", "")


def write_framework_plist(fw: Path, sdk: str, min_os: str) -> None:
    plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>{LIB_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>{BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>{LIB_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>{SUPPORTED_PLATFORM[sdk]}</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>{min_os}</string>
</dict>
</plist>
"""
    (fw / "Info.plist").write_text(plist)


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the azahar core libraries for iOS/tvOS")
    parser.add_argument("-p", "--platforms", nargs="+", choices=PLATFORMS.keys(),
                        help="platforms to build (default: OS64)")
    parser.add_argument("-a", "--all-platforms", action="store_true", help="build all four platforms")
    parser.add_argument("-c", "--clean", action="store_true", help="delete each platform's build dir first")
    parser.add_argument("-v", "--verbose", action="store_true", help="print every command run")
    args = parser.parse_args()

    platforms = list(PLATFORMS) if args.all_platforms else (args.platforms or ["OS64"])
    try:
        builder = AzaharBuilder(verbose=args.verbose, clean=args.clean)
        for platform in platforms:
            builder.build_platform(platform)
        xcfw = builder.create_xcframework()
    except BuildError as e:
        log(f"Build failed: {e}", "error")
        return 1
    except KeyboardInterrupt:
        log("Build interrupted", "error")
        return 130
    log(f"Done: {xcfw}", "success")
    return 0


if __name__ == "__main__":
    sys.exit(main())
