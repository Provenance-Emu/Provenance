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
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# core dir -> Core.plist path (relative to the core dir) of the package's Swift target
CORES = {
    "PPSSPP": "PVPPSSPP/Core.plist",
    "ep128emu": "PVEP128EmuCore/Resources/Core.plist",
    "snes9x": "PVSNES/Core.plist",
    "FCEU": "PVFCEU/Core.plist",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/Resources/Core.plist",
    "Mupen64Plus": "Sources/PVMupen/Resources/Core.plist",
    "Azahar": "PVAzahar/Core.plist",
    "Dolphin": "PVDolphin/Core.plist",
    "emuThree": "PVEmuThree/Core.plist",
}

# cores the shipping app takes from their packages -> their CorePlist.swift
SHIPPED_AS_PACKAGES = {
    "PPSSPP": "PVPPSSPPCore/Core/CorePlist.swift",
    "Dolphin": "PVDolphinCore/Core/CorePlist.swift",
    "emuThree": "PVEmuThreeCore/Core/CorePlist.swift",
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


class CorePackageLayoutTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_source_targets_are_libraries_with_separate_languages(self):
        for relative in ["PVCoreBridgeRetro", "Cores/ep128emu", "Cores/emuThree", "Cores/Dolphin", "Cores/PPSSPP"]:
            with self.subTest(package=relative):
                if relative == "Cores/Dolphin" and not (
                    ROOT / relative / "dolphin-ios/build/xcframework/PVlibDolphin.xcframework"
                ).is_dir():
                    self.skipTest("Dolphin source layout requires its prepared native binary")
                result = subprocess.run(
                    ["swift", "package", "describe", "--type", "json"], cwd=ROOT / relative,
                    check=True, capture_output=True, text=True,
                )
                description = json.loads(result.stdout)
                for target in description["targets"]:
                    if target["type"] in {"test", "binary"}:
                        continue
                    self.assertEqual(target["type"], "library", target["name"])
                    extensions = {Path(source).suffix for source in target.get("sources", [])}
                    self.assertFalse(".swift" in extensions and extensions & {".m", ".mm", ".c", ".cpp"}, target["name"])
                    base = ROOT / relative / target["path"]
                    for source in target.get("sources", []):
                        self.assertTrue((base / source).is_file(), source)


class PPSSPPPackageTests(unittest.TestCase):
    def test_bridge_resources_and_swift_runtime_lookup(self):
        core = ROOT / "Cores/PPSSPP"
        source = (core / "PVPPSSPPCore/Core/PVPPSSPPCore.mm").read_text()
        self.assertIn("SWIFTPM_MODULE_BUNDLE", source)
        self.assertNotIn("bundleForClass:", source)
        self.assertIn('stringByAppendingPathComponent:@"flash0"', source)
        self.assertTrue((core / "cmake/assets/flash0/font/ltn0.pgf").is_file())
        video = (core / "PVPPSSPPCore/Core/PVPPSSPPCore+Video.mm").read_text()
        for controller in ["PPSSPPVulkanViewController", "PPSSPPOGLViewController"]:
            self.assertIn(f"[PV_PPSSPP_SWIFT_CLASS({controller}) alloc]", video)
        interop = (core / "PVPPSSPPCore/Core/PPSSPPSwiftInterop.h").read_text()
        self.assertIn('NSClassFromString(@"PVPPSSPP." #name)', interop)

    @unittest.skipUnless(shutil.which("xcrun"), "Clang module validation requires Xcode")
    def test_native_modules_can_be_imported_together(self):
        module_map = ROOT / "Cores/PPSSPP/SwiftPM/include/module.modulemap"
        names = re.findall(r"^module (\w+)", module_map.read_text(), re.M)
        self.assertTrue(names, "native module map is empty")
        result = subprocess.run(
            ["xcrun", "clang", "-fmodules", "-x", "objective-c", "-fsyntax-only", "-",
             f"-fmodule-map-file={module_map}"],
            input="".join(f"@import {name};\n" for name in names),
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_native_engine_is_source_built(self):
        package = dump_package("PPSSPP")
        self.assertFalse(any(target["type"] == "binary" for target in package["targets"]))
        targets = {target["name"]: target for target in package["targets"]}
        sources = [source for target in package["targets"] for source in target.get("sources", [])]
        self.assertEqual(len(sources), len(set(sources)), "duplicate native archive members")
        self.assertIn("libretro_ppsspp/Core/System.cpp", sources)
        self.assertIn("PVPPSSPPCore/Core/MemArenaDarwin.cpp", sources)
        self.assertIn("PVPPSSPPCore/Core/iOSCoreAudio.mm", sources)
        self.assertNotIn("libretro_ppsspp/ios/iOSCoreAudio.mm", sources)
        self.assertEqual(len(targets["PVPPSSPP"]["sources"]), 8)
        self.assertEqual(len(targets["PVPPSSPPBridge"]["sources"]), 12)
        self.assertEqual(targets["PVPPSSPPBridge"]["resources"][0]["path"], "cmake/assets")


if __name__ == "__main__":
    unittest.main()
