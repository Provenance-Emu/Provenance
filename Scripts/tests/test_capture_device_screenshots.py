"""Capture orchestration regressions; no device or emulator required."""
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "capture_device_screenshots", Path(__file__).parents[1] / "capture_device_screenshots.py")
capture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capture)
GAME = {"title": "240pSuite", "system": "com.provenance.nes", "md5": "fixture"}


class FakeAPI:
    base = "http://fixture"

    def __init__(self, games=(), screenshot_error=False, restore_error=False, boot_ok=True):
        self.games = list(games)
        self.screenshot_error = screenshot_error
        self.restore_error = restore_error
        self.boot_ok = boot_ok
        self.calls = []
        self.running = False

    def get(self, path, **query):
        if path.endswith("/library"):
            return {"ok": True, "data": {"games": self.games, "count": len(self.games)}}
        data = {"bootupCompleted": True, "shader": "Always(lcd)", "pixelateLibraryArtwork": False}
        if self.running:
            data["core"] = {"running": True}
        return {"ok": True, "data": data}

    def post(self, path, payload=None, **query):
        self.calls.append((path, payload))
        if path.endswith("/boot"):
            self.running = self.boot_ok
            return {"ok": self.boot_ok, "error": "fixture refusal"}
        if path.endswith("/exit"):
            self.running = False
        if self.restore_error and path.endswith("/shader") and payload == {"filter": "lcd"}:
            raise ConnectionError("restore unavailable")
        return {"ok": True}

    def screenshot(self, source="window"):
        if self.screenshot_error:
            raise ConnectionError("capture unavailable")
        return b"fixture png"


class CaptureTests(unittest.TestCase):
    def run_capture(self, api):
        with tempfile.TemporaryDirectory() as out, \
                patch.object(capture, "DebugAPI", return_value=api), \
                patch.object(capture.time, "sleep"), \
                patch("sys.argv", ["capture", "--out", out, "--shaders", "none"]), \
                patch("sys.stdout", new_callable=io.StringIO), \
                patch("sys.stderr", new_callable=io.StringIO):
            return capture.main()

    def assert_restored(self, api):
        self.assertEqual(api.calls[-2:], [
            ("/api/debug/shader", {"filter": "lcd"}),
            ("/api/debug/pixelate", {"enabled": False}),
        ])

    def test_library_capture_failure_restores_settings(self):
        api = FakeAPI(screenshot_error=True)
        with self.assertRaisesRegex(ConnectionError, "capture unavailable"):
            self.run_capture(api)
        self.assert_restored(api)

    def test_pixelation_restored_even_if_shader_restore_fails(self):
        api = FakeAPI(restore_error=True)
        with self.assertRaisesRegex(ConnectionError, "restore unavailable"):
            self.run_capture(api)
        self.assert_restored(api)

    def test_empty_library_is_unsuccessful(self):
        api = FakeAPI()
        self.assertEqual(self.run_capture(api), 1)
        self.assert_restored(api)

    def test_refused_boot_is_unsuccessful(self):
        api = FakeAPI([GAME], boot_ok=False)
        self.assertEqual(self.run_capture(api), 1)
        self.assert_restored(api)

    def test_gameplay_capture_succeeds_and_restores_settings(self):
        api = FakeAPI([GAME])
        self.assertEqual(self.run_capture(api), 0)
        self.assert_restored(api)


if __name__ == "__main__":
    unittest.main()
