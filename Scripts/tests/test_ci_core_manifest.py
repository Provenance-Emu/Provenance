"""Tests for Scripts/ci/ci-core-manifest.py using synthetic IPAs."""
import importlib.util
import io
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/ci/ci-core-manifest.py"
spec = importlib.util.spec_from_file_location("ci_core_manifest", SCRIPT)
manifest = importlib.util.module_from_spec(spec)
sys.modules["ci_core_manifest"] = manifest  # dataclasses look the module up
spec.loader.exec_module(manifest)

APP = "Payload/Provenance.app"


def core_plist(identifier: str) -> bytes:
    return plistlib.dumps({"PVCoreIdentifier": identifier, "PVProjectName": identifier})


def make_ipa(path: Path) -> None:
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr(f"{APP}/Provenance", b"x" * 10)
        # xcodeproj-style core: Core.plist inside the framework
        zf.writestr(f"{APP}/Frameworks/PVSNES.framework/PVSNES", b"x" * 100)
        zf.writestr(f"{APP}/Frameworks/PVSNES.framework/Core.plist", core_plist("com.provenance.core.snes9x"))
        # SwiftPM-style core: code in the -Dynamic framework, Core.plist in a root resource bundle
        zf.writestr(f"{APP}/Frameworks/PVStella-Dynamic.framework/PVStella-Dynamic", b"x" * 100)
        zf.writestr(f"{APP}/PVCoreStella_PVStella.bundle/Core.plist", core_plist("com.provenance.core.stella"))
        # nested Core.plist deeper in a bundle must not count
        zf.writestr(f"{APP}/Other.bundle/Sub/Core.plist", core_plist("com.provenance.core.bogus"))
        zf.writestr(f"{APP}/Frameworks/mgba.libretro.framework/mgba", b"x" * 50)
        zf.writestr(f"{APP}/Frameworks/PVLibrary.framework/PVLibrary", b"x" * 70)


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ipa = Path(self.tmp.name) / "Provenance-iOS.ipa"
        make_ipa(self.ipa)

    def tearDown(self):
        self.tmp.cleanup()

    def test_both_core_layouts_are_native_cores(self):
        report = manifest.read_ipa(str(self.ipa))
        self.assertEqual(
            manifest.core_identifiers(report),
            ["com.provenance.core.snes9x", "com.provenance.core.stella"],
        )

    def test_package_core_reported_by_bundle_name(self):
        report = manifest.read_ipa(str(self.ipa))
        names = {f.name for f in report.frameworks if f.is_native_core}
        self.assertIn("PVCoreStella_PVStella.bundle", names)

    def test_identifiers_cli(self):
        out = subprocess.run(
            [sys.executable, str(SCRIPT), "--identifiers", str(self.ipa)],
            check=True, capture_output=True, text=True,
        ).stdout.splitlines()
        self.assertEqual(out, [
            "Provenance-iOS.ipa\tcom.provenance.core.snes9x",
            "Provenance-iOS.ipa\tcom.provenance.core.stella",
        ])


if __name__ == "__main__":
    unittest.main()
