#!/usr/bin/env python3
"""Tests for fetch_slang_shaders.py's archive unpacking and manifest."""

import io
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fetch_slang_shaders as fetch  # noqa: E402

SHADER = {"passes": [{"vertexSource": "v", "fragmentSource": "f"}], "parameters": [
    {"name": "a", "desc": "A", "initial": 0.5, "minimum": 0, "maximum": 1, "step": 0.1}],
    "luts": [], "historyCount": 0}


def archive(members: dict) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as zf:
        for name, data in members.items():
            zf.writestr(name, data)
    return buffer.getvalue()


class UnpackTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_unpacks_shader_and_lut(self):
        data = archive({"shader.json": json.dumps(SHADER), "mask__mask.png": b"png"})
        fetch.unpack_preset(data, self.tmp / "p")
        self.assertTrue((self.tmp / "p" / "shader.json").exists())
        self.assertEqual((self.tmp / "p" / "mask__mask.png").read_bytes(), b"png")

    def test_rejects_parent_traversal(self):
        data = archive({"shader.json": "{}", "../evil__x.png": b"x"})
        with self.assertRaises(fetch.FetchError):
            fetch.unpack_preset(data, self.tmp / "p")
        self.assertFalse((self.tmp / "evil__x.png").exists())

    def test_rejects_absolute_path(self):
        with self.assertRaises(fetch.FetchError):
            fetch.unpack_preset(archive({"shader.json": "{}", "/etc/x__y": b"x"}), self.tmp / "p")

    def test_rejects_symlink(self):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as zf:
            zf.writestr("shader.json", "{}")
            link = zipfile.ZipInfo("lut__link.png")
            link.external_attr = (0o120777 << 16)
            zf.writestr(link, "/etc/passwd")
        with self.assertRaises(fetch.FetchError):
            fetch.unpack_preset(buffer.getvalue(), self.tmp / "p")

    def test_requires_shader_json(self):
        with self.assertRaises(fetch.FetchError):
            fetch.unpack_preset(archive({"lut__a.png": b"x"}), self.tmp / "p")

    def test_skips_macos_metadata(self):
        data = archive({"shader.json": "{}", "__MACOSX/._shader.json": b"junk"})
        fetch.unpack_preset(data, self.tmp / "p")
        self.assertEqual(sorted(p.name for p in (self.tmp / "p").iterdir()), ["shader.json"])


class ManifestTests(unittest.TestCase):
    def test_entry_fields_and_compute_exclusion(self):
        entry = fetch.manifest_entry("crt/test", SHADER, {})
        self.assertEqual(entry["category"], "crt")
        self.assertEqual(entry["passes"], 1)
        self.assertEqual(entry["parameters"][0]["label"], "A")
        self.assertNotIn("excluded", entry)
        compute = dict(SHADER, passes=[{"vertexSource": "", "fragmentSource": "kernel void k() {}"}])
        self.assertEqual(fetch.manifest_entry("x/y", compute, {})["excluded"], "uses compute kernels")
        self.assertEqual(fetch.manifest_entry("x/y", SHADER, {"x/y": "broken"})["excluded"], "broken")


if __name__ == "__main__":
    unittest.main()
