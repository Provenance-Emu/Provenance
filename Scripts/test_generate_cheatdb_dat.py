#!/usr/bin/env python3
"""Unit tests for generate_cheatdb DAT parsing (MD5 map keys vs libretro No-Intro layout)."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "generate_cheatdb.py"
_spec = importlib.util.spec_from_file_location("generate_cheatdb", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)
parse_dat_file = _mod.parse_dat_file
_build_md5_base_index = _mod._build_md5_base_index
_lookup_md5_fuzzy = _mod._lookup_md5_fuzzy
_dat_stem_match_base = _mod._dat_stem_match_base


class ParseDatFileTests(unittest.TestCase):
    def test_parentheses_inside_quoted_rom_name(self):
        """No-Intro rom filenames contain (Region); old [^)]* regex broke before md5."""
        dat = """clrmamepro (
\tname "Nintendo - Game Boy"
)
game (
\tname "3 Choume no Tama - Tama and Friends - 3 Choume Obake Panic!! (Japan)"
\tregion "Japan"
\trom ( name "3 Choume no Tama - Tama and Friends - 3 Choume Obake Panic!! (Japan).gb" size 131072 crc B61CD120 md5 93CEA7134DB2A28B06D30729AD460DD6 sha1 0982BCC82DEB9C4DB08E602A22A2BB4F31E7E6AE )
)
"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".dat", delete=False, encoding="utf-8") as f:
            f.write(dat)
            path = Path(f.name)
        try:
            result = parse_dat_file(path)
        finally:
            path.unlink(missing_ok=True)
        self.assertEqual(
            result.get("3 Choume no Tama - Tama and Friends - 3 Choume Obake Panic!! (Japan)"),
            "93cea7134db2a28b06d30729ad460dd6",
        )

    def test_simple_rom_line(self):
        dat = """game (
\tname "1942"
\trom ( name "1942.gb" size 65536 crc 00000000 md5 AABBCCDD00112233445566778899AABB sha1 0987654321098765432109876543210987654321 )
)
"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".dat", delete=False, encoding="utf-8") as f:
            f.write(dat)
            path = Path(f.name)
        try:
            result = parse_dat_file(path)
        finally:
            path.unlink(missing_ok=True)
        self.assertEqual(result.get("1942"), "aabbccdd00112233445566778899aabb")

    def test_multiple_rom_lines_last_stem_wins(self):
        dat = """game (
\tname "Disc"
\trom ( name "disc.cue" size 1 crc 00000000 md5 11111111111111111111111111111111 sha1 1111111111111111111111111111111111111111 )
\trom ( name "disc.bin" size 2 crc 00000000 md5 22222222222222222222222222222222 sha1 2222222222222222222222222222222222222222 )
)
"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".dat", delete=False, encoding="utf-8") as f:
            f.write(dat)
            path = Path(f.name)
        try:
            result = parse_dat_file(path)
        finally:
            path.unlink(missing_ok=True)
        self.assertEqual(result.get("disc"), "22222222222222222222222222222222")


class Md5FuzzyLookupTests(unittest.TestCase):
    def test_dat_stem_strips_track_and_regions(self):
        s = "18 Wheeler - American Pro Trucker (USA) (Track 3)"
        self.assertEqual(_dat_stem_match_base(s), "18 Wheeler - American Pro Trucker")

    def test_fuzzy_short_cht_title_with_japanese_hint(self):
        sys_md5 = {
            "18 Wheeler - American Pro Trucker (Japan) (Track 3)": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "18 Wheeler - American Pro Trucker (USA) (Track 3)": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        }
        idx = _build_md5_base_index(sys_md5)
        m = _lookup_md5_fuzzy(sys_md5, idx, "18 Wheeler (Japanese)")
        self.assertEqual(m, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")

    def test_fuzzy_ambiguous_region_without_hint_returns_none(self):
        sys_md5 = {
            "Bomberman Online (USA) (Track 1)": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "Bomberman Online (Europe) (Track 1)": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        }
        idx = _build_md5_base_index(sys_md5)
        self.assertIsNone(_lookup_md5_fuzzy(sys_md5, idx, "Bomberman Online"))

    def test_fuzzy_exact_still_preferred(self):
        # Keys match parse_dat_file: rom filename stem without extension.
        sys_md5 = {"Exact Title (USA)": "cccccccccccccccccccccccccccccccc"}
        idx = _build_md5_base_index(sys_md5)
        self.assertEqual(_lookup_md5_fuzzy(sys_md5, idx, "Exact Title (USA)"), "cccccccccccccccccccccccccccccccc")


if __name__ == "__main__":
    unittest.main()
