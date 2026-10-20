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


if __name__ == "__main__":
    unittest.main()
