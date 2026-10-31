"""Failure reporting must preserve diagnostics hidden by archive formatters."""

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "ci" / "print-build-failure-logs.sh"
ROOT = Path(__file__).resolve().parents[2]


class BuildFailureLogsTests(unittest.TestCase):
    def test_reports_script_failure_from_raw_archive_log(self):
        with tempfile.TemporaryDirectory() as directory:
            pretty = Path(directory) / "testflight.log"
            raw = Path(directory) / "raw archive.log"
            pretty.write_text("Copying app resources\n")
            raw.write_text("codesign: errSecInternalComponent\nThe following build commands failed:\n"
                           "\tPhaseScriptExecution Generate\\ Frameworks\n")
            result = subprocess.run(["bash", str(SCRIPT), str(pretty), str(raw)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("errSecInternalComponent", result.stdout)
            self.assertIn("PhaseScriptExecution", result.stdout)
            self.assertIn(str(raw), result.stdout)

    def test_release_log_remains_available_when_archive_never_started(self):
        with tempfile.TemporaryDirectory() as directory:
            release = Path(directory) / "testflight.log"
            release.write_text("release: error: missing native slice\n")
            result = subprocess.run(["bash", str(SCRIPT), str(release), str(release.parent / "absent")],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("missing native slice", result.stdout)

    def test_missing_logs_warn_without_hiding_original_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(["bash", str(SCRIPT), str(Path(directory) / "absent")],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("::warning::", result.stdout)

    def test_workflow_uploads_the_unformatted_archive_log(self):
        workflow = (ROOT / ".github/workflows/testflight.yml").read_text()
        upload = workflow.split("- name: Upload raw log on failure", 1)[1].split("- name:", 1)[0]
        self.assertIn("${{ env.RAW_ARCHIVE_LOG }}", upload)
        self.assertIn("xcodebuild-${{ matrix.platform == 'ios' && 'iOS' || 'tvOS' }}.log", workflow)


if __name__ == "__main__":
    unittest.main()
