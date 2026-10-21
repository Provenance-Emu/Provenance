"""IPA streaming must preserve the existing payload format and the source archive."""
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "Scripts/ci/package-ipa.sh"


@unittest.skipUnless(shutil.which("zip"), "requires the ZIP CLI used by CI")
class IPAPackagingTests(unittest.TestCase):
    def fixture(self, root):
        app = root / "Archive with spaces/Products/Applications/Provenance.app"
        app.mkdir(parents=True)
        (app / "Info.plist").write_text("fixture plist")
        binary = app / "Provenance"
        binary.write_bytes(b"fixture executable")
        binary.chmod(0o755)
        (app / "shared.bin").write_bytes(b"shared bytes")
        (app / "alias.bin").symlink_to("shared.bin")
        for directory in ["PlugIns/Widget.appex", "Watch/Companion.app", "Extensions/Example.appex"]:
            path = app / directory
            path.mkdir(parents=True)
            (path / "Info.plist").write_text(directory)
        return app

    def snapshot(self, root):
        return {str(p.relative_to(root)): (p.lstat().st_mode,
                os.readlink(p) if p.is_symlink() else p.read_bytes() if p.is_file() else None)
                for p in root.rglob("*")}

    def zip_manifest(self, path):
        with zipfile.ZipFile(path) as archive:
            return {entry.filename: (archive.read(entry), entry.external_attr)
                    for entry in archive.infolist()}

    def test_full_and_extension_free_match_copy_based_payloads(self):
        with tempfile.TemporaryDirectory(prefix="ipa-parity-") as temporary:
            root = Path(temporary)
            app = self.fixture(root)
            original = self.snapshot(app)
            for without_extensions in [False, True]:
                with self.subTest(without_extensions=without_extensions):
                    reference = root / ("reference-noext" if without_extensions else "reference-full")
                    payload = reference / "Payload/Provenance-iOS.app"
                    shutil.copytree(app, payload, symlinks=True)
                    if without_extensions:
                        for directory in ["PlugIns", "Watch", "Extensions"]:
                            shutil.rmtree(payload / directory)
                    subprocess.run(["zip", "-qr", str(reference / "reference.ipa"), "Payload"],
                                   cwd=reference, check=True)
                    output = root / ("no extensions.ipa" if without_extensions else "full.ipa")
                    command = ["bash", str(HELPER), str(app), str(output), "Provenance-iOS.app"]
                    if without_extensions:
                        command.append("--without-extensions")
                    subprocess.run(command, check=True)
                    self.assertEqual(self.zip_manifest(output), self.zip_manifest(reference / "reference.ipa"))
                    self.assertEqual(self.snapshot(app), original)

    def test_zip_failure_cleans_staging_and_preserves_source(self):
        with tempfile.TemporaryDirectory(prefix="ipa-failure-") as temporary:
            root = Path(temporary)
            app = self.fixture(root)
            original = self.snapshot(app)
            tools = root / "tools"
            tools.mkdir()
            fake_zip = tools / "zip"
            fake_zip.write_text("#!/bin/sh\nexit 14\n")
            fake_zip.chmod(0o755)
            scratch = root / "scratch"
            scratch.mkdir()
            env = dict(os.environ, TMPDIR=str(scratch), PATH=str(tools) + os.pathsep + os.environ["PATH"])
            result = subprocess.run(["bash", str(HELPER), str(app), str(root / "failed.ipa"), "Provenance-iOS.app"], env=env)
            self.assertEqual(result.returncode, 14)
            self.assertEqual(list(scratch.iterdir()), [])
            self.assertEqual(self.snapshot(app), original)


if __name__ == "__main__":
    unittest.main()
