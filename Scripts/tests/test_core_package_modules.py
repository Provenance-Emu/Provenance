"""A package core's Swift module must equal its Core.plist PVPrincipleClass prefix,
or NSClassFromString returns nil and the core never instantiates (Mupen, 2026-10-12)."""
import plistlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# core dir -> Core.plist path (relative to the core dir) of the package's Swift target
CORES = {
    "snes9x": "PVSNES/Core.plist",
    "FCEU": "PVFCEU/Core.plist",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/Resources/Core.plist",
    "Mupen64Plus": "Sources/PVMupen/Resources/Core.plist",
    "Azahar": "PVAzahar/Core.plist",
    "Dolphin": "PVDolphin/Core.plist",
}


def swift_target_names(manifest: str) -> set[str]:
    return set(re.findall(r'\.target\(\s*name:\s*"([^"]+)"', manifest))


class ModuleNameTests(unittest.TestCase):
    def test_principal_class_module_is_a_package_target(self):
        for core, plist_rel in CORES.items():
            with self.subTest(core=core):
                plist = plistlib.loads((ROOT / "Cores" / core / plist_rel).read_bytes())
                module = plist["PVPrincipleClass"].split(".")[0]
                manifest = (ROOT / "Cores" / core / "Package.swift").read_text()
                self.assertIn(module, swift_target_names(manifest))


if __name__ == "__main__":
    unittest.main()
