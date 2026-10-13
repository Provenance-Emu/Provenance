"""Runs swap_core_to_package.rb against a temp copy of the shipping project."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/dev/swap_core_to_package.rb"
TARGETS = ["Provenance", "Provenance (AppStore)", "Provenance-XL", "Provenance-Lite (AppStore)"]


def have_gem() -> bool:
    return subprocess.run(["ruby", "-e", 'require "xcodeproj"'], capture_output=True).returncode == 0


@unittest.skipUnless(have_gem(), "xcodeproj gem not installed")
class SwapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        shutil.copytree(ROOT / "Provenance.xcodeproj", self.tmp / "Provenance.xcodeproj")
        (self.tmp / "Provenance.xcworkspace").mkdir()
        shutil.copy(ROOT / "Provenance.xcworkspace/contents.xcworkspacedata",
                    self.tmp / "Provenance.xcworkspace/contents.xcworkspacedata")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_script(self, *args):
        env = dict(os.environ, PROJECT_DIR=str(self.tmp))  # keep PATH: the gem lives in the user's Ruby
        return subprocess.run(["ruby", str(SCRIPT), *args], env=env, capture_output=True, text=True)

    def objects(self):
        out = subprocess.check_output(["plutil", "-convert", "json", "-o", "-",
                                       str(self.tmp / "Provenance.xcodeproj/project.pbxproj")])
        return json.loads(out)["objects"]

    def test_snes9x_swap(self):
        self.assertEqual(self.run_script("snes9x", "--verify").returncode, 1)
        res = self.run_script("snes9x", "--apply")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.run_script("snes9x", "--verify").returncode, 0)
        subprocess.run(["plutil", "-lint", str(self.tmp / "Provenance.xcodeproj/project.pbxproj")], check=True)

        objs = self.objects()
        targets = {o["name"]: o for o in objs.values() if o.get("isa") == "PBXNativeTarget"}
        for t in TARGETS:
            deps = [objs[d]["productName"] for d in targets[t].get("packageProductDependencies", [])]
            self.assertIn("PVSNES9x-Dynamic", deps, t)
        old = [o for o in objs.values() if o.get("isa") == "PBXFileReference"
               and o.get("path") in ("PVSNES.framework", "snes9x.framework")]
        self.assertEqual(old, [])
        ws = (self.tmp / "Provenance.xcworkspace/contents.xcworkspacedata").read_text()
        self.assertNotIn("Cores/snes9x/PVSNES9x.xcodeproj", ws)

    def test_apply_is_idempotent(self):
        self.assertEqual(self.run_script("fceu", "--apply").returncode, 0)
        before = (self.tmp / "Provenance.xcodeproj/project.pbxproj").read_text()
        self.assertEqual(self.run_script("fceu", "--apply").returncode, 0)
        self.assertEqual(before, (self.tmp / "Provenance.xcodeproj/project.pbxproj").read_text())

    def test_mupen_embeds_all_plugins(self):
        self.assertEqual(self.run_script("mupen64plus", "--apply").returncode, 0)
        objs = self.objects()
        targets = {o["name"]: o for o in objs.values() if o.get("isa") == "PBXNativeTarget"}
        for t in TARGETS:
            deps = {objs[d]["productName"] for d in targets[t].get("packageProductDependencies", [])}
            self.assertTrue({"PVMupenGameCore-Dynamic", "PVMupen64PlusRspHLE-Dynamic", "PVRSPCXD4-Dynamic",
                             "PVMupen64PlusVideoRice-Dynamic", "PVMupen64PlusVideoGlideN64-Dynamic"} <= deps, t)


if __name__ == "__main__":
    unittest.main()
