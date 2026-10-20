"""Package cores must resolve their principal class and resources the SwiftPM way.

- The Swift target that owns Core.plist must be named like the PVPrincipleClass module prefix,
  or NSClassFromString returns nil and the core never instantiates (Mupen, 2026-10-12).
- In package builds a core's `resourceBundle` must be `Bundle.module`: resources sit in the
  <Package>_<Target>.bundle, not in the framework that `Bundle(for:)` returns.
"""
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# core dir -> Core.plist path (relative to the core dir) of the package's Swift target
CORES = {
    "ep128emu": "PVEP128EmuCore/Resources/Core.plist",
    "snes9x": "PVSNES/Core.plist",
    "FCEU": "PVFCEU/Core.plist",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/Resources/Core.plist",
    "Mupen64Plus": "Sources/PVMupen/Resources/Core.plist",
    "Azahar": "PVAzahar/Core.plist",
    "Dolphin": "PVDolphin/Core.plist",
}

# cores the shipping app takes from their packages -> their CorePlist.swift
SHIPPED_AS_PACKAGES = {
    "ep128emu": "PVEP128EmuCore/CorePlist.swift",
    "snes9x": "PVSNES/SNES/CorePlist.swift",
    "FCEU": "CorePlist.swift",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/CorePlist.swift",
    "Mupen64Plus": "Sources/PVMupen/CorePlist.swift",
}


def dump_package(core: str) -> dict:
    out = subprocess.run(["swift", "package", "dump-package"], cwd=ROOT / "Cores" / core,
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out)


class ModuleNameTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_core_plist_owner_is_the_principal_class_module(self):
        for core, plist_rel in CORES.items():
            with self.subTest(core=core):
                plist = plistlib.loads((ROOT / "Cores" / core / plist_rel).read_bytes())
                module = plist["PVPrincipleClass"].split(".")[0]
                owners = []
                for target in dump_package(core)["targets"]:
                    base = target.get("path") or f"Sources/{target['name']}"
                    for resource in target.get("resources", []):
                        if str(Path(base) / resource["path"]) == plist_rel:
                            owners.append(target["name"])
                self.assertEqual(owners, [module])


def swift_package_branch(source: str) -> str:
    match = re.search(r"#if SWIFT_PACKAGE\n(.*?)\n#else", source, re.S)
    return match.group(1) if match else ""


class ResourceBundleTests(unittest.TestCase):
    def test_package_resource_bundle_is_bundle_module(self):
        for core, rel in SHIPPED_AS_PACKAGES.items():
            with self.subTest(core=core):
                source = (ROOT / "Cores" / core / rel).read_text()
                package_branch = swift_package_branch(source)
                accessor = re.search(r"override var resourceBundle: Bundle \{ ([^}]+?) \}", source)
                self.assertIsNotNone(accessor, "no resourceBundle override")
                expr = accessor.group(1).strip()
                if expr != "Bundle.module":
                    name = expr.split(".")[-1]
                    definition = re.search(rf"static var {name}: Bundle \{{ ([^}}]+?) \}}", package_branch)
                    self.assertIsNotNone(definition, f"{name} not defined under SWIFT_PACKAGE")
                    expr = definition.group(1).strip()
                self.assertEqual(expr, "Bundle.module")


class LibretroPackageLayoutTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_libretro_targets_are_libraries_with_separate_languages(self):
        for relative in ["PVCoreBridgeRetro", "Cores/ep128emu"]:
            with self.subTest(package=relative):
                result = subprocess.run(
                    ["swift", "package", "describe", "--type", "json"], cwd=ROOT / relative,
                    check=True, capture_output=True, text=True,
                )
                description = json.loads(result.stdout)
                for target in description["targets"]:
                    if target["type"] == "test":
                        continue
                    self.assertEqual(target["type"], "library", target["name"])
                    extensions = {Path(source).suffix for source in target.get("sources", [])}
                    self.assertFalse(".swift" in extensions and extensions & {".m", ".mm", ".c", ".cpp"}, target["name"])
                    base = ROOT / relative / target["path"]
                    for source in target.get("sources", []):
                        self.assertTrue((base / source).is_file(), source)


class RetroLinkageTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform == "darwin" and shutil.which("xcrun"), "requires Apple SDKs")
    def test_c_callbacks_and_vulkan_headers(self):
        root = ROOT

        def run(*args):
            return subprocess.run(args, check=True, capture_output=True, text=True).stdout

        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            # Stub only the JITManager dependency; compile the actual callback implementations with release optimization.
            jit = (root / "PVCoreBridgeRetro/Sources/PVLibRetro/PVLibRetro+JIT.swift").read_text()
            jit = jit.replace(
                "#if !os(tvOS)\nimport JITManager\n#endif", "enum DOLJitManager { static let acquired = false }"
            )
            (t / "JIT.swift").write_text(jit)
            policy = root / "PVCoreBridgeRetro/Sources/PVLibRetro/ThinVFSDiskImagePolicy.swift"
            run(
                "xcrun",
                "swiftc",
                "-parse-as-library",
                "-O",
                "-whole-module-optimization",
                "-emit-library",
                str(t / "JIT.swift"),
                str(policy),
                "-o",
                str(t / "support.dylib"),
            )
            symbols = run("nm", "-gU", str(t / "support.dylib"))
            for name in ("_pvjit_acquired", "_pv_thin_vfs_should_memory_map"):
                self.assertIn(name, symbols, f"Callback not exported: {name}")
            (t / "client.c").write_text(
                """#include <stdbool.h>
        #include <stdint.h>
        extern bool pvjit_acquired(void);
        extern bool pv_thin_vfs_should_memory_map(const char *, uint32_t, uint32_t, int64_t);
        int main(void) {
         if (pvjit_acquired()) return 1;
         if (!pv_thin_vfs_should_memory_map("disc.iso", 1, 0, 1024)) return 2;
         if (pv_thin_vfs_should_memory_map(0, 1, 0, 1024)) return 3;
         return 0;
        }
        """
            )
            run("xcrun", "clang", str(t / "client.c"), str(t / "support.dylib"), "-o", str(t / "client"))
            run(str(t / "client"))
            print("PASS: optimized Swift callbacks exported, linked from C, and executed")
            (t / "headers.mm").write_text(
                '#include "PVCoreBridgeRetro/Sources/ExternalHeaders/MoltenVK/vulkan/vk_platform.h"\n'
                '#include "PVCoreBridgeRetro/Sources/ExternalHeaders/MoltenVK/vk_video/vulkan_video_codecs_common.h"\n'
            )
            for sdk in ("macosx", "iphoneos", "iphonesimulator", "appletvos", "appletvsimulator"):
                sdkroot = run("xcrun", "--sdk", sdk, "--show-sdk-path").strip()
                target = {
                    "macosx": "arm64-apple-macos14",
                    "iphoneos": "arm64-apple-ios17",
                    "iphonesimulator": "arm64-apple-ios17-simulator",
                    "appletvos": "arm64-apple-tvos17",
                    "appletvsimulator": "arm64-apple-tvos17-simulator",
                }[sdk]
                run(
                    "xcrun",
                    "clang++",
                    "-fsyntax-only",
                    "-fmodules",
                    "-fcxx-modules",
                    "-Werror=module-import-in-extern-c",
                    "-isysroot",
                    sdkroot,
                    "-target",
                    target,
                    "-I",
                    str(root),
                    str(t / "headers.mm"),
                )
                print(f"PASS: Vulkan headers with C++ modules ({sdk})")


if __name__ == "__main__":
    unittest.main()
