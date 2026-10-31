"""Exercise release alignment against real tracked manifests and resolver files."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


CHECKER = Path(__file__).resolve().parents[1] / "dev/check_skinkit_alignment.py"
REVISION = "599030369e2ed8d052618128e169e6d08405c527"


class ReleaseAlignmentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.roots = [Path(self.temp.name) / name for name in ("provenance", "ifly", "icube")]
        declarations = ["PVUI/Package.swift", "Project.swift", "Source/iOS/App/Project.swift"]
        self.manifests = []
        for root, relative in zip(self.roots, declarations):
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            manifest = root / relative
            manifest.parent.mkdir(parents=True, exist_ok=True)
            prefix = "requirement: " if root == self.roots[2] else ""
            manifest.write_text(f'.package(url: "https://github.com/Provenance-Emu/SkinKit.git", {prefix}.exact("0.1.0"))')
            self.manifests.append(manifest)
            self.write_pin(root, REVISION, "0.1.0")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)

    def write_pin(self, root, revision, version):
        state = {"revision": revision}
        if version:
            state["version"] = version
        (root / "Package.resolved").write_text(json.dumps({"pins": [{"identity": "skinkit", "state": state}]}))

    def check(self, version=True):
        command = ["python3", str(CHECKER), "--expected-revision", REVISION]
        for option, root in zip(("--provenance", "--ifly", "--icube"), self.roots):
            command.extend([option, str(root)])
        if version:
            command.extend(["--expected-version", "0.1.0"])
        return subprocess.run(command, capture_output=True, text=True)

    def test_exact_releases_and_matching_resolver_commits(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("PASS:"), 6)

    def test_tag_cannot_hide_a_different_commit(self):
        for revision in ("a" * 40, None, ""):
            with self.subTest(revision=revision):
                self.write_pin(self.roots[1], revision, "0.1.0")
                self.assertEqual(self.check().returncode, 1)

    def test_missing_or_wrong_resolver_version_is_rejected(self):
        for version in (None, "0.1.1"):
            with self.subTest(version=version):
                self.write_pin(self.roots[0], REVISION, version)
                self.assertEqual(self.check().returncode, 1)

    def test_release_mode_rejects_revision_only_declarations(self):
        self.manifests[0].write_text(f'.package(url: "https://github.com/Provenance-Emu/SkinKit", revision: "{REVISION}")')
        self.assertEqual(self.check().returncode, 1)

    def test_revision_mode_still_checks_pre_release_baselines(self):
        for root, manifest in zip(self.roots, self.manifests):
            manifest.write_text(f'.package(url: "https://github.com/Provenance-Emu/SkinKit", .revision("{REVISION}"))')
            self.write_pin(root, REVISION, None)
        self.assertEqual(self.check(version=False).returncode, 0)

    def test_floating_requirement_is_not_an_exact_release(self):
        self.manifests[0].write_text('.package(url: "https://github.com/Provenance-Emu/SkinKit", from: "0.1.0")')
        self.assertEqual(self.check().returncode, 2)


if __name__ == "__main__":
    unittest.main()
