"""Tests the catalog boundary that decides which multiplayer facts are trusted."""
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "netplay/build_multiplayer_catalog.py"
SPEC = importlib.util.spec_from_file_location("multiplayer_catalog", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MultiplayerCatalogTests(unittest.TestCase):
    def extract(self, body):
        return MODULE.extract(("<datafile>" + body + "</datafile>").encode())

    def test_local_and_network_player_counts_are_distinct(self):
        result = self.extract('<game><id>RABC01</id><input players="2"/><wi-fi players="12"/></game>')
        self.assertEqual(result["com.provenance.wii:RABC01"]["modes"], [
            {"kind": "sharedConsole", "maxPlayers": 2},
            {"kind": "nativeNetwork", "maxPlayers": 12},
        ])

    def test_one_local_player_does_not_prove_single_player_only(self):
        record = self.extract('<game><id>GABC01</id><input players="1"/></game>')["com.provenance.gamecube:GABC01"]
        self.assertFalse(record["singlePlayerOnly"])
        self.assertEqual(record["modes"], [])

    def test_external_console_peripherals_remain_unverified(self):
        self.assertEqual(self.extract('<game><id>GABC01</id><input players="4"><control type="gba"/></input></game>'), {})

    def test_custom_titles_and_malformed_counts_are_not_inferred(self):
        self.assertEqual(self.extract('<game><id>GABC01</id><type>CUSTOM</type><input players="4"/></game>'), {})
        self.assertEqual(self.extract('<game><id>GABC01</id><input players="1-4"/></game>'), {})

    def test_system_and_full_serial_are_preserved(self):
        record = self.extract('<game><id>GABC01</id><input players="4"/></game>')
        self.assertEqual(list(record), ["com.provenance.gamecube:GABC01"])
        self.assertEqual(record["com.provenance.gamecube:GABC01"]["reference"], "https://www.gametdb.com/Wii/GABC01")


if __name__ == "__main__":
    unittest.main()
