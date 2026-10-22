#!/usr/bin/env python3
"""Compile/run real validation and dispatch; no ROM fixtures or dependency builds.

DOLPHIN_SOURCE_ROOT may point to a read-only initialized Dolphin source checkout.
Host tests use dependency shells for CoreLoader/PVDolphinCore and a provider
fixture; all new Swift method bodies and the C++ validation helper are production.
--sdk-check also syntax-checks the actual Objective-C++ reader and category,
then typechecks its Swift importer/forwarder for iOS and tvOS. Only the unrelated
PVCoreObjCBridge base/protocols are stubbed; DiscIO and platform headers are real.
"""
import argparse
import os
import shutil
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Scripts/tests/fixtures/library_disc_identity"
CORE = ROOT / "Cores/Dolphin/PVDolphinCore/Core"
DOLPHIN = Path(os.environ.get("DOLPHIN_SOURCE_ROOT", ROOT / "Cores/Dolphin/dolphin-ios"))


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def check_sdk(work, protocol):
    for sdk, target in [("iphoneos", "arm64-apple-ios17.0"), ("appletvos", "arm64-apple-tvos17.0")]:
        directory = work / sdk
        directory.mkdir()
        sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
        run("xcrun", "swiftc", "-sdk", sdk_path, "-target", target, "-emit-module",
            "-module-name", "PVCoreBridge", "-emit-module-path", directory / "PVCoreBridge.swiftmodule",
            "-emit-objc-header-path", directory / "PVCoreBridge-Swift.h", protocol)
        (directory / "module.modulemap").write_text(
            'module PVCoreBridge { header "PVCoreBridge-Swift.h" export * }\n')
        base = directory / "PVCoreObjCBridge"
        base.mkdir()
        (base / "PVCoreObjCBridge.h").write_text(
            '#import <Foundation/Foundation.h>\n'
            '@protocol ObjCBridgedCoreBridge @end\n'
            '@protocol PVGameCubeSystemResponderClient @end\n'
            '@protocol PVWiiSystemResponderClient @end\n'
            '@protocol EmulatorCoreViewportPositioning @end\n'
            '@interface PVCoreObjCBridge: NSObject @end\n')
        run("xcrun", "clang++", "-fsyntax-only", "-std=c++2b", "-fobjc-arc", "-fmodules", "-fcxx-modules",
            "-Werror=protocol", "-Werror=incomplete-implementation", "-DGLES_SILENCE_DEPRECATION=1",
            "-include", CORE / "DolphinCxxCompat.h", "-isysroot", sdk_path, "-target", target,
            "-I", directory, "-I", DOLPHIN / "Source/Core", "-I", DOLPHIN / "Externals/fmt/fmt/include",
            CORE / "PVDolphinCore+LibraryIdentity.mm")
        bridge = directory / "PVDolphinBridge"
        bridge.mkdir()
        (bridge / "module.modulemap").write_text(
            'module PVDolphinBridge { header "' + str(CORE / "PVDolphinCore+LibraryIdentity.h") + '" export * }\n')
        principal = directory / "PVDolphinCore.swift"
        principal.write_text("import Foundation\nopen class PVDolphinCore: NSObject {}\n")
        run("xcrun", "swiftc", "-typecheck", "-sdk", sdk_path, "-target", target,
            "-I", directory, "-I", bridge, "-module-name", "PVDolphin", principal,
            CORE / "PVDolphinCore+LibraryIdentity.swift")
        print("SDK syntax and Swift importer passed:", sdk, flush=True)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--sdk-check", action="store_true", help="Also check actual iOS/tvOS reader syntax and Swift importer")
options = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="pv-library-identity-") as directory:
    work = Path(directory)
    run("xcrun", "clang++", "-std=c++20", "-Wall", "-Wextra", "-Werror", "-I", CORE,
        "-I", DOLPHIN / "Source/Core", FIXTURES / "validation.cpp", "-o", work / "validation")
    run(work / "validation")
    protocol = ROOT / "PVCoreBridge/Sources/PVCoreBridge/Features/LibraryDiscIdentityReading.swift"
    run("xcrun", "swiftc", "-emit-library", "-emit-module", "-module-name", "PVCoreBridge",
        "-emit-objc-header-path", work / "PVCoreBridge-Swift.h", protocol,
        "-o", work / "libPVCoreBridge.dylib", "-emit-module-path", work / "PVCoreBridge.swiftmodule")
    shell = work / "CoreLoader.swift"
    shell.write_text("public final class CoreLoader {}\n")
    run("xcrun", "swiftc", "-I", work, "-L", work, "-lPVCoreBridge",
        "-Xlinker", "-rpath", "-Xlinker", work, shell,
        ROOT / "PVCoreLoader/Sources/PVCoreLoader/CoreLoader+LibraryIdentity.swift",
        FIXTURES / "main.swift", "-o", work / "dispatch")
    run(work / "dispatch")
    # Compile the production principal-class forwarder against an Objective-C
    # provider fixture and the real generated Swift protocol header.
    shutil.copy(FIXTURES / "Bridge.h", work / "Bridge.h")
    (work / "module.modulemap").write_text(
        'module PVDolphinBridge { header "Bridge.h" export * }\n')
    run("xcrun", "clang", "-fobjc-arc", "-Werror=protocol", "-I", work,
        "-I", FIXTURES, "-c", FIXTURES / "Bridge.m", "-o", work / "bridge.o")
    principal = work / "PVDolphinCore.swift"
    principal.write_text("import Foundation\npublic class PVDolphinCore: NSObject {\n"
                         '    public override init() { fatalError("Must not create a core") }\n}\n')
    run("xcrun", "swiftc", "-emit-library", "-emit-module", "-module-name", "PVDolphin",
        "-I", work, "-L", work, "-lPVCoreBridge", "-Xlinker", "-rpath", "-Xlinker", work,
        principal, CORE / "PVDolphinCore+LibraryIdentity.swift", work / "bridge.o",
        "-o", work / "libPVDolphin.dylib", "-emit-module-path", work / "PVDolphin.swiftmodule")
    main = work / "main.swift"
    main.write_text((FIXTURES / "main.swift").read_text() + "\nimport PVDolphin\n"
                    'let principalIdentity = CoreLoader.readLibraryDiscIdentity(at: url, coreClassName: "PVDolphin.PVDolphinCore")\n'
                    'precondition(principalIdentity?["discNumber"] as? Int == 1)\n'
                    'precondition(principalIdentity?["revision"] as? Int == 7)\n'
                    'precondition(CoreLoader.readLibraryDiscIdentity(at: URL(fileURLWithPath: "/bad"), coreClassName: "PVDolphin.PVDolphinCore") == nil)\n')
    run("xcrun", "swiftc", "-I", work, "-L", work, "-lPVCoreBridge", "-lPVDolphin",
        "-Xlinker", "-rpath", "-Xlinker", work, shell,
        ROOT / "PVCoreLoader/Sources/PVCoreLoader/CoreLoader+LibraryIdentity.swift",
        main, "-o", work / "principal-dispatch")
    run(work / "principal-dispatch")
    if options.sdk_check:
        check_sdk(work, protocol)
print("Identity validation and typed dispatch passed")
