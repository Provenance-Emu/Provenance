#!/usr/bin/env python3
"""
Dolphin Core Build Script for Provenance

This script builds the Dolphin emulator core for iOS and tvOS platforms,
creating a universal XCFramework that can be used in Provenance.
"""

import os
import sys
import subprocess
import shutil
import signal
import argparse
import glob
import multiprocessing
from pathlib import Path
from typing import List, Dict, Optional, Tuple, Set


# Configuration
CONFIG = {
    "build_target": "Release",
    "framework_name": "PVlibDolphin",
    "ios_deployment_target": "16.4",
    "tvos_deployment_target": "16.4",
    "platforms": {
        "OS64": {  # iOS device (arm64)
            "deployment_target": "16.4",
            "arch_flags": "-mcpu=apple-a10 -mtune=apple-a15 -march=armv8-a+simd+crc+crypto",
            "suffix": "-ios",
            "xcode_platform": "iphoneos",
        },
        "SIMULATORARM64": {  # iOS simulator (arm64)
            "deployment_target": "16.4",
            "arch_flags": "",  # No architecture-specific flags for simulator
            "suffix": "-ios-sim",
            "xcode_platform": "iphonesimulator",
        },
        "TVOS": {  # tvOS device (arm64)
            "deployment_target": "16.4",
            "arch_flags": "-mcpu=apple-a10 -mtune=apple-a15 -march=armv8-a+simd+crc+crypto",
            "suffix": "-tvos",
            "xcode_platform": "appletvos",
        },
        "SIMULATORARM64_TVOS": {  # tvOS simulator (arm64)
            "deployment_target": "16.4",
            "arch_flags": "",  # No architecture-specific flags for simulator
            "suffix": "-tvos-sim",
            "xcode_platform": "appletvsimulator",
        }
    }
}


class BuildError(Exception):
    """Exception raised for build errors."""
    pass


class DolphinBuilder:
    """Handles building Dolphin core for multiple platforms and creating an XCFramework."""

    def __init__(self, verbose: bool = False, clean: bool = False, static: bool = True):
        """Initialize the DolphinBuilder."""
        self.verbose = verbose
        self.clean = clean
        self.static = static
        self.script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
        self.repo_root_dir = self.script_dir / "dolphin-ios"
        self.build_dir = self.script_dir / "build"
        self.xcframework_dir = self.build_dir / "xcframework"
        self.processes = {}
        self.dylibs = {}
        self.frameworks = {}

        # Ensure necessary directories exist
        self.build_dir.mkdir(exist_ok=True)
        self.xcframework_dir.mkdir(exist_ok=True)

        # Set compiler paths
        self.cc = subprocess.check_output(["xcrun", "-find", "clang"]).decode().strip()
        self.cxx = subprocess.check_output(["xcrun", "-find", "clang++"]).decode().strip()

        # Set environment variables for compiler detection
        os.environ["CC"] = self.cc
        os.environ["CXX"] = self.cxx

        # Check for required tools
        self._check_required_tools()

    def _check_required_tools(self):
        """Check if required build tools are installed."""
        # Check for Homebrew CMake first
        homebrew_cmake = "/opt/homebrew/bin/cmake"
        if os.path.exists(homebrew_cmake):
            self.cmake_path = homebrew_cmake
            self._log(f"Found CMake at: {self.cmake_path}", "debug")
        else:
            # Try xcrun
            try:
                self.cmake_path = subprocess.check_output(["xcrun", "-find", "cmake"]).decode().strip()
                self._log(f"Found CMake at: {self.cmake_path}", "debug")
            except subprocess.CalledProcessError:
                # Fallback to regular path
                try:
                    self.cmake_path = subprocess.check_output(["which", "cmake"]).decode().strip()
                    self._log(f"Found CMake at: {self.cmake_path}", "debug")
                except subprocess.CalledProcessError:
                    raise BuildError("Error: cmake not found. Please install it or ensure it's in your PATH.")

        # Find xcodebuild
        try:
            self.xcodebuild_path = subprocess.check_output(["xcrun", "-find", "xcodebuild"]).decode().strip()
            self._log(f"Found xcodebuild at: {self.xcodebuild_path}", "debug")
        except subprocess.CalledProcessError:
            raise BuildError("Error: xcodebuild not found. Please ensure Xcode is installed properly.")

        # Optional tools
        self.has_ninja = False

        # Check for Homebrew Ninja first
        homebrew_ninja = "/opt/homebrew/bin/ninja"
        if os.path.exists(homebrew_ninja):
            self.ninja_path = homebrew_ninja
            self.has_ninja = True
            self._log(f"Found Ninja at: {self.ninja_path}", "debug")
        else:
            # Try xcrun
            try:
                self.ninja_path = subprocess.check_output(["xcrun", "-find", "ninja"]).decode().strip()
                self.has_ninja = True
                self._log(f"Found Ninja at: {self.ninja_path}", "debug")
            except subprocess.CalledProcessError:
                # Fallback to regular path
                try:
                    self.ninja_path = subprocess.check_output(["which", "ninja"]).decode().strip()
                    self.has_ninja = True
                    self._log(f"Found Ninja at: {self.ninja_path}", "debug")
                except subprocess.CalledProcessError:
                    self._log("Ninja not found. Will use default CMake generator.", "warning")

    def _log(self, message, level="info"):
        """Log a message with appropriate formatting."""
        prefix_map = {
            "info": "ℹ️",
            "success": "✅",
            "error": "❌",
            "warning": "⚠️",
            "debug": "🔍",
            "build": "🔨",
            "package": "📦"
        }

        prefix = prefix_map.get(level, "ℹ️")
        print(f"{prefix} {message}")

        if level == "error":
            sys.stderr.flush()
        else:
            sys.stdout.flush()

    def build_all(self, platforms=None):
        """Build for specified platforms and create XCFramework.

        Args:
            platforms: List of platform names to build. If None, builds all platforms.
        """
        try:
            # Build for each platform
            for platform, config in CONFIG["platforms"].items():
                if platforms and platform not in platforms:
                    self._log(f"Skipping build for {platform} (not in requested platforms)", "info")
                    continue

                self._log(f"Starting build for {platform}...", "build")
                self.build_platform(platform)

            # Create XCFramework
            self._log("All builds completed successfully!", "success")
            self.create_xcframework()

            return True
        except BuildError as e:
            self._log(f"Build failed: {str(e)}", "error")
            return False
        except KeyboardInterrupt:
            self._log("Build interrupted by user", "warning")
            return False
        except Exception as e:
            self._log(f"Unexpected error: {str(e)}", "error")
            return False

    def build_platform(self, platform: str) -> bool:
        """Build Dolphin for a specific platform."""
        print(f"🔨 Starting build for {platform}...")

        # Get platform-specific configuration
        platform_config = CONFIG["platforms"][platform]
        arch_flags = platform_config["arch_flags"]
        deployment_target = platform_config["deployment_target"]
        suffix = platform_config["suffix"]
        xcode_platform = platform_config["xcode_platform"]

        # Create build directory
        cmake_build_dir = self.repo_root_dir / f"build-{xcode_platform}-{CONFIG['build_target']}"

        # Clean build directory if requested
        if self.clean and cmake_build_dir.exists():
            print(f"🧹 Cleaning build directory for {platform}...")
            import shutil
            shutil.rmtree(cmake_build_dir)

        cmake_build_dir.mkdir(exist_ok=True)

        # Base optimization flags (common to all platforms)
        base_optimization_flags = "-Ofast"
        # -ffast-math -fno-strict-aliasing -ftree-vectorize -flto=thin -fomit-frame-pointer -funsafe-math-optimizations -fvectorize"

        # Curl build fixes - apply to all platforms to resolve build issues
        curl_fixes = (
            "-DHAVE_POSIX_STRERROR_R=1 -DHAVE_STRERROR_R=1 -DHAVE_FCNTL_O_NONBLOCK=1 "
            "-Dsread=read -Dswrite=write -DSIZEOF_CURL_OFF_T=8 -DHAVE_STRUCT_TIMEVAL=1 "
            "-DHAVE_STRUCT_SOCKADDR_IN=1 -DHAVE_NETINET_IN_H=1 -DHAVE_ARPA_INET_H=1 "
            "-DHAVE_SYS_SOCKET_H=1 -DHAVE_SOCKET=1 -DHAVE_CONNECT=1 -DHAVE_RECV=1 -DHAVE_SEND=1 "
            "-DHAVE_BIND=1 -DHAVE_LISTEN=1 -DHAVE_ACCEPT=1 -DHAVE_SOCKADDR_IN6=1 "
            "-DHAVE_STRUCT_STAT=1 -DHAVE_FSTAT=1 -DHAVE_OPEN=1 -DO_WRONLY=1 -DO_CREAT=64 "
            "-DO_EXCL=128 -DS_ISREG=1 -DHAVE_SELECT=1 -DHAVE_POLL=1 "
            "-DHAVE_NETDB_H=1 -DHAVE_GETHOSTBYNAME=1 -DHAVE_STRUCT_HOSTENT=1 "
            "-DHAVE_GETHOSTBYADDR=1 -DHAVE_GETADDRINFO=1 -DHAVE_FREEADDRINFO=1 "
            "-DHAVE_SYS_STAT_H=1 -DHAVE_FCNTL_H=1 -DHAVE_UNISTD_H=1 -DHAVE_SYS_TYPES_H=1 "
            "-DHAVE_POLL_H=1 -DHAVE_SYS_POLL_H=1"
        )

        # Combine flags with ARM64-only enforcement
        arm64_defines = "-D_M_ARM_64 -U_M_X86_64 -U_M_IX86"  # ARM64 only, explicitly undefine x86 macros
        c_flags = f"-fPIC {base_optimization_flags} -w {arm64_defines} {curl_fixes}".strip()
        cxx_flags = f"-fPIC {base_optimization_flags} -w {arm64_defines} {curl_fixes}".strip()

        # Add architecture-specific flags only for device builds (not simulators)
        if platform not in ["SIMULATORARM64", "SIMULATOR_TVOS"]:
            arch_flags = platform_config["arch_flags"]
        else:
            arch_flags = ""  # No architecture-specific flags for simulators

        # Apply architecture flags if present
        if arch_flags:
            c_flags += f" {arch_flags}"
            cxx_flags += f" {arch_flags}"

        # Explicitly set deployment target flags to override toolchain defaults
        if platform in ["SIMULATORARM64", "SIMULATOR_TVOS"]:
            if platform == "SIMULATORARM64":
                c_flags += f" -mios-simulator-version-min={deployment_target}"
                cxx_flags += f" -mios-simulator-version-min={deployment_target}"
            elif platform == "SIMULATOR_TVOS":
                c_flags += f" -mtvos-simulator-version-min={deployment_target}"
                cxx_flags += f" -mtvos-simulator-version-min={deployment_target}"
        else:
            if platform == "OS64":
                c_flags += f" -miphoneos-version-min={deployment_target}"
                cxx_flags += f" -miphoneos-version-min={deployment_target}"
            elif platform == "TVOS":
                c_flags += f" -mtvos-version-min={deployment_target}"
                cxx_flags += f" -mtvos-version-min={deployment_target}"

        # Additional linker optimizations
        linker_flags = "-Wl,-dead_strip"

        # Configure CMake command
        cmake_cmd = [
            self.cmake_path, str(self.repo_root_dir),
        ]

        # Add generator if Ninja is available
        if self.has_ninja:
            cmake_cmd.extend(["-G", "Ninja"])
            cmake_cmd.append(f"-DCMAKE_MAKE_PROGRAM={self.ninja_path}")

        # FORCE ARM64-ONLY for ALL platforms (no x86_64 support)
        cmake_cmd.append("-DCMAKE_OSX_ARCHITECTURES=arm64")
        # Let the iOS toolchain set CMAKE_SYSTEM_PROCESSOR based on ARCHS

        if platform in ["SIMULATORARM64", "SIMULATORARM64_TVOS"]:
            # Explicitly set the correct SDK for simulator builds
            if platform == "SIMULATORARM64":
                simulator_sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"]).decode().strip()
                cmake_cmd.append(f"-DCMAKE_OSX_SYSROOT={simulator_sdk}")
            elif platform == "SIMULATORARM64_TVOS":
                simulator_sdk = subprocess.check_output(["xcrun", "--sdk", "appletvsimulator", "--show-sdk-path"]).decode().strip()
                cmake_cmd.append(f"-DCMAKE_OSX_SYSROOT={simulator_sdk}")

        # iOS toolchain and platform configuration
        cmake_cmd.extend([
            f"-DCMAKE_TOOLCHAIN_FILE={str(self.repo_root_dir / 'Externals/ios-cmake/ios.toolchain.cmake')}",
            f"-DPLATFORM={platform}",
            f"-DDEPLOYMENT_TARGET={deployment_target}",
            "-DARCHS=arm64",  # Force ARM64 architecture for all builds
            f"-DCMAKE_BUILD_TYPE={CONFIG['build_target']}",
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",  # Fix pugixml compatibility
        ])

        # Override deployment target at CMake level to ensure it's respected
        if platform in ["SIMULATORARM64", "SIMULATORARM64_TVOS"]:
            if platform == "SIMULATORARM64":
                cmake_cmd.append(f"-DCMAKE_OSX_DEPLOYMENT_TARGET={deployment_target}")
            elif platform == "SIMULATORARM64_TVOS":
                cmake_cmd.append(f"-DCMAKE_TVOS_DEPLOYMENT_TARGET={deployment_target}")
        else:
            if platform == "OS64":
                cmake_cmd.append(f"-DCMAKE_OSX_DEPLOYMENT_TARGET={deployment_target}")
            elif platform == "TVOS":
                cmake_cmd.append(f"-DCMAKE_TVOS_DEPLOYMENT_TARGET={deployment_target}")

        # Continue with the rest of the CMake arguments
        cmake_cmd.extend([
            f"-DCMAKE_C_FLAGS={c_flags}",
            f"-DCMAKE_CXX_FLAGS={cxx_flags}",
            f"-DCMAKE_EXE_LINKER_FLAGS={linker_flags}",
            f"-DCMAKE_SHARED_LINKER_FLAGS={linker_flags}",
            "-DENABLE_VISIBILITY=ON",
            "-DENABLE_BITCODE=OFF",
            "-DENABLE_ARC=ON",
            "-DUSE_SYSTEM_ZSTD=OFF",
            "-DUSE_SYSTEM_MINIZIP=OFF",
            "-DUSE_SYSTEM_LZMA=OFF",
            "-DUSE_SYSTEM_BZIP2=OFF",
            "-DIOS=ON",
            "-DENABLE_ANALYTICS=NO",
            "-DUSE_SYSTEM_LIBS=OFF",
            "-DENABLE_TESTS=OFF",
            "-DCMAKE_POLICY_DEFAULT_CMP0080=NEW",
            "-DCMAKE_POLICY_VERSION=3.19",
            f"-DBUILD_SHARED_LIBS={'OFF' if self.static else 'ON'}",
            # Force external libraries to respect our BUILD_SHARED_LIBS setting
            "-DLZ4_BUNDLED_MODE=ON",  # Prevent lz4 from overriding BUILD_SHARED_LIBS
            "-DXXHASH_BUNDLED_MODE=ON",  # Prevent xxhash from overriding BUILD_SHARED_LIBS
            "-DCMAKE_XCODE_ATTRIBUTE_ENABLE_ARC=YES",
            # ARM64-only enforcement - disable x86_64 specific code
            "-DENABLE_X64_DEC=OFF",
            "-DUSE_X64_DEC=OFF",
            "-DENABLE_GENERIC=OFF",  # Allow proper ARM64 context detection
            "-DCMAKE_SYSTEM_PROCESSOR=aarch64",  # Force aarch64 to override any detection
            # CMake variables for architecture detection
            "-D_M_ARM_64:BOOL=ON",  # CMake variable for ARM64
            "-D_M_X86_64:BOOL=OFF",  # Explicitly disable x86_64
        ])

        # Enable generic build for simulator platforms (no JIT needed)
        if platform in ["SIMULATORARM64", "SIMULATOR_TVOS"]:
            # cmake_cmd.append("-DENABLE_GENERIC=ON")  # Removed to allow proper ARM64 context detection
            # Don't set _M_X86_64 for generic builds to avoid x86_64-specific code compilation
            pass  # ARM64 context will be used instead of generic

        # Execute CMake configure
        self._log(f"Configuring CMake for {platform}...", "build")
        os.chdir(cmake_build_dir)

        try:
            if self.verbose:
                self._log(f"Running: {' '.join(cmake_cmd)}", "debug")

            subprocess.check_call(cmake_cmd)

            # Build with appropriate command
            if self.has_ninja:
                self._log(f"Building {platform} with Ninja...", "build")
                build_cmd = [self.ninja_path, "-j", str(multiprocessing.cpu_count())]
            else:
                self._log(f"Building {platform} with CMake build...", "build")
                build_cmd = [self.cmake_path, "--build", ".", "-j", str(multiprocessing.cpu_count())]

            if self.verbose:
                self._log(f"Running: {' '.join(build_cmd)}", "debug")

            subprocess.check_call(build_cmd)

            # Find the built dylib - CMake doesn't use our suffix, so search for the actual filename
            dylib_search_dir = cmake_build_dir / "Source/iOS/Library"
            dylib_patterns = [
                str(dylib_search_dir / f"libdolphin{suffix}.1.dylib"),  # Try with suffix first
                str(dylib_search_dir / "libdolphin-ios.1.dylib"),        # Fallback to standard name
                str(dylib_search_dir / "libdolphin.1.dylib"),            # Fallback to minimal name
            ]

            dylibs = []
            for pattern in dylib_patterns:
                dylibs = glob.glob(pattern)
                if dylibs:
                    break

            if not dylibs:
                raise BuildError(f"Could not find built dylib for {platform} (xcode_platform: {xcode_platform}). Searched: {dylib_patterns}")

            self.dylibs[platform] = dylibs[0]
            self._log(f"Build completed for {platform}", "success")

        except subprocess.CalledProcessError as e:
            raise BuildError(f"Build failed for {platform} with exit code {e.returncode}")

    def create_framework(self, dylib_path: str, platform: str):
        """Create a framework from a dylib."""
        framework_name = CONFIG["framework_name"]
        framework_path = self.xcframework_dir / f"{framework_name}{CONFIG['platforms'][platform]['suffix']}.framework"

        # Remove existing framework if it exists
        if framework_path.exists():
            shutil.rmtree(framework_path)

        # Create framework directory structure
        framework_path.mkdir(parents=True)

        # Get the actual filename without path
        dylib_filename = os.path.basename(dylib_path)
        platform_suffix = CONFIG['platforms'][platform]['suffix']

        # Copy dylib to framework and rename it to match framework name
        binary_name = f"{framework_name}{platform_suffix}"
        shutil.copy(dylib_path, framework_path / binary_name)

        # Make sure the binary is executable
        os.chmod(framework_path / binary_name, 0o755)

        # Fix the install name to match the framework structure
        subprocess.check_call([
            "install_name_tool",
            "-id",
            f"@rpath/{framework_name}{platform_suffix}.framework/{binary_name}",
            str(framework_path / binary_name)
        ])

        # Create Info.plist
        info_plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>{binary_name}</string>
    <key>CFBundleIdentifier</key>
    <string>org.dolphin-emu.{binary_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>{binary_name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>16.4</string>
</dict>
</plist>
"""

        with open(framework_path / "Info.plist", "w") as f:
            f.write(info_plist)

        self._log(f"Framework created at {framework_path}", "success")
        self.frameworks[platform] = str(framework_path)
        return framework_path

    def create_xcframework(self):
        """Create XCFramework from individual frameworks."""
        self._log("Starting XCFramework creation process...", "package")

        # Create frameworks for each platform that was built in this session
        for platform, dylib_path in self.dylibs.items():
            self.create_framework(dylib_path, platform)

        # Find ALL existing .framework directories in the xcframework folder
        framework_paths = list(self.xcframework_dir.glob("*.framework"))

        if not framework_paths:
            self._log("No frameworks found in xcframework directory", "warning")
            return

        # Create XCFramework
        framework_name = CONFIG["framework_name"]
        xcframework_path = self.xcframework_dir / f"{framework_name}.xcframework"

        # Remove existing XCFramework if it exists
        if xcframework_path.exists():
            shutil.rmtree(xcframework_path)

        # Build the xcodebuild command
        xcframework_cmd = [self.xcodebuild_path, "-create-xcframework", "-output", str(xcframework_path)]

        # Add ALL found frameworks to command
        for framework_path in framework_paths:
            xcframework_cmd.extend(["-framework", str(framework_path)])

        self._log(f"Creating XCFramework with {len(framework_paths)} frameworks...", "package")
        self._log(f"Executing: {' '.join(xcframework_cmd)}", "debug")

        try:
            subprocess.check_call(xcframework_cmd)
            self._log(f"XCFramework created at {xcframework_path}", "success")

            # List the contents of the XCFramework
            self._log("XCFramework contents:", "info")
            for item in xcframework_path.glob("**/*"):
                if item.is_dir():
                    self._log(f"  📁 {item.relative_to(xcframework_path)}", "debug")
                else:
                    self._log(f"  📄 {item.relative_to(xcframework_path)}", "debug")

            # Copy XCFramework to the expected output location if BUILT_PRODUCTS_DIR is set
            built_products_dir = os.environ.get("BUILT_PRODUCTS_DIR")
            if built_products_dir:
                output_path = Path(built_products_dir) / f"{framework_name}.xcframework"
                self._log(f"Copying XCFramework to {output_path}", "package")

                if output_path.exists():
                    shutil.rmtree(output_path)

                shutil.copytree(xcframework_path, output_path)

        except subprocess.CalledProcessError as e:
            raise BuildError(f"XCFramework creation failed with exit code {e.returncode}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Build Dolphin core for iOS/tvOS platforms")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")
    parser.add_argument("-p", "--platforms", nargs="+", choices=CONFIG["platforms"].keys(),
                        help="Specific platforms to build (default: OS64)")
    parser.add_argument("-a", "--all-platforms", action="store_true",
                        help="Build all supported platforms (default: false)")
    parser.add_argument("-c", "--clean", action="store_true",
                        help="Clean build directories before building (default: false)")
    parser.add_argument("-s", "--static", action="store_true", default=True,
                        help="Build static libraries (default: true)")
    parser.add_argument("-d", "--dynamic", action="store_true",
                        help="Build dynamic libraries (overrides --static)")
    parser.add_argument("-x", "--xcframework-only", action="store_true",
                        help="Only create XCFramework from existing frameworks (skip building)")
    args = parser.parse_args()

    # Set up signal handler for clean termination
    def signal_handler(sig, frame):
        print("\n🛑 Build interrupted! Cleaning up...")
        sys.exit(130)  # Standard exit code for Ctrl+C

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Determine build type (static vs dynamic)
    build_static = args.static and not args.dynamic  # dynamic overrides static

    # Start the build process
    builder = DolphinBuilder(verbose=args.verbose, clean=args.clean, static=build_static)

    # Handle XCFramework-only mode
    if args.xcframework_only:
        print("Creating XCFramework from existing frameworks...")
        try:
            builder.create_xcframework()
            print("\n✅ XCFramework creation completed successfully!")
            return 0
        except Exception as e:
            print(f"\n❌ XCFramework creation failed: {e}")
            return 1

    # Determine which platforms to build
    platforms_to_build = None  # None means all platforms in the build_all method

    if args.all_platforms:
        # Build all platforms
        print("Building all supported platforms")
    elif args.platforms:
        # Build specific platforms
        platforms_to_build = args.platforms
        print(f"Building specified platforms: {', '.join(platforms_to_build)}")
    else:
        # Default: only build iOS device (OS64)
        platforms_to_build = ["OS64", "TVOS"]
        print("Building default platform: OS64 (iOS device)")

    if builder.build_all(platforms=platforms_to_build):
        print("\n✅ Build completed successfully!")
        return 0
    else:
        print("\n❌ Build failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
