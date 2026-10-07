#!/usr/bin/env python3
"""Unit tests for generate_uti_declarations --update-plist (merge, idempotence, --check)."""

import contextlib
import importlib.util
import io
import plistlib
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "generators" / "generate_uti_declarations.py"
_spec = importlib.util.spec_from_file_location("generate_uti_declarations", _SCRIPT)
gen = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(gen)

# Two mapped systems plus one the generator has no UTI for (its extensions go to the base type).
SYSTEMS = [
    {"PVSystemIdentifier": "com.provenance.nes", "PVSupportedExtensions": ["nes", "unf"]},
    {"PVSystemIdentifier": "com.provenance.snes", "PVSupportedExtensions": ["smc", "sfc"]},
    {"PVSystemIdentifier": "com.provenance.unmapped", "PVSupportedExtensions": ["xyz"]},
]

# A hand-maintained plist: an XML comment, an &apos; escape, hand-added UTIs, a hand-added
# extension (.rvz) inside a generator-owned type, a stale system type and no SNES type yet.
INFO_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- hand-written comment that a plist round trip would drop -->
	<key>NSMotionUsageDescription</key>
	<string>Provenance uses your device&apos;s accelerometer.</string>
	<key>UTExportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.data</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Old ROM description</string>
			<key>UTTypeIdentifier</key>
			<string>com.provenance.rom</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>rvz</string>
				</array>
			</dict>
		</dict>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>com.provenance.rom</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Nintendo Entertainment System ROM</string>
			<key>UTTypeIdentifier</key>
			<string>com.provenance.rom.nes</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>nes</string>
				</array>
			</dict>
		</dict>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>com.provenance.rom</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Retired System ROM</string>
			<key>UTTypeIdentifier</key>
			<string>com.provenance.rom.retired</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>old</string>
				</array>
			</dict>
		</dict>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.zip-archive</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Provenance Save Bundle</string>
			<key>UTTypeIdentifier</key>
			<string>com.provenance.pvsave</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>pvsave</string>
				</array>
			</dict>
		</dict>
	</array>
	<key>UTImportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.zip-archive</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Delta Skin</string>
			<key>UTTypeIdentifier</key>
			<string>com.rileytestut.delta.skin</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>deltaskin</string>
				</array>
			</dict>
		</dict>
	</array>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Log File</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.log</string>
			</array>
		</dict>
		<dict>
			<key>CFBundleTypeName</key>
			<string>ROM</string>
			<key>LSHandlerRank</key>
			<string>Owner</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>com.provenance.rom.nes</string>
				<string>com.provenance.rom</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
"""

HAND_ADDED_UTIS = ["com.provenance.pvsave", "com.rileytestut.delta.skin", "com.provenance.rom.retired"]


def _entries(path: Path, key: str) -> dict:
    return {e["UTTypeIdentifier"]: e for e in plistlib.loads(path.read_bytes())[key]}


def _ids(path: Path, key: str) -> list:
    return [e["UTTypeIdentifier"] for e in plistlib.loads(path.read_bytes())[key]]


class UtiMergeTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.systems = self.dir / "systems.plist"
        self.systems.write_bytes(plistlib.dumps(SYSTEMS))
        self.info = self.dir / "Info.plist"
        self.info.write_text(INFO_PLIST, encoding="utf-8")

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = gen.main(["--systems-plist", str(self.systems), *args])
            except SystemExit as exc:  # argparse errors
                code = exc.code
        return code, out.getvalue()


class MergeTests(UtiMergeTestCase):
    def test_hand_added_utis_preserved_untouched_and_in_order(self):
        code, _ = self.run_main("--update-plist", str(self.info))
        self.assertEqual(code, 0)
        exported_ids = _ids(self.info, gen.EXPORTED_KEY)
        for ident in ("com.provenance.pvsave", "com.provenance.rom.retired"):
            self.assertIn(ident, exported_ids)
        self.assertIn("com.rileytestut.delta.skin", _ids(self.info, gen.IMPORTED_KEY))

        # Each hand-added <dict> is still present byte for byte, and their relative order holds.
        text = self.info.read_text(encoding="utf-8")
        for ident in HAND_ADDED_UTIS:
            start = INFO_PLIST.rindex("<dict>", 0, INFO_PLIST.index(f"<string>{ident}</string>"))
            end = INFO_PLIST.index("</dict>\n\t\t</dict>", start) + len("</dict>\n\t\t</dict>")
            self.assertIn(INFO_PLIST[start:end], text, ident)
        original_order = ["com.provenance.rom", "com.provenance.rom.nes",
                          "com.provenance.rom.retired", "com.provenance.pvsave"]
        self.assertEqual([i for i in exported_ids if i in original_order], original_order)

    def test_unrelated_formatting_survives(self):
        self.run_main("--update-plist", str(self.info))
        text = self.info.read_text(encoding="utf-8")
        self.assertIn("<!-- hand-written comment that a plist round trip would drop -->", text)
        self.assertIn("device&apos;s", text)
        self.assertIn("<!DOCTYPE plist", text)

    def test_generator_utis_are_updated_and_added_without_removals(self):
        self.run_main("--update-plist", str(self.info))
        exported = _entries(self.info, gen.EXPORTED_KEY)

        base = exported["com.provenance.rom"]
        self.assertEqual(base["UTTypeDescription"], "ROM file")
        exts = base["UTTypeTagSpecification"]["public.filename-extension"]
        self.assertEqual(exts[0], "rvz")  # hand-added extension kept, in place
        self.assertIn("xyz", exts)  # unmapped system's extension added
        self.assertIn("public.data", base["UTTypeConformsTo"])

        nes = exported["com.provenance.rom.nes"]
        self.assertEqual(nes["UTTypeTagSpecification"]["public.filename-extension"], ["nes", "unf"])
        self.assertEqual(nes["UTTypeTagSpecification"]["public.mime-type"],
                         ["application/x-provenance-nes-rom"])

        snes = exported["com.provenance.rom.snes"]  # was missing, now added
        self.assertEqual(snes["UTTypeTagSpecification"]["public.filename-extension"], ["sfc", "smc"])
        ids = _ids(self.info, gen.EXPORTED_KEY)
        self.assertGreater(ids.index("com.provenance.rom.snes"), ids.index("com.provenance.rom.nes"))

        for ident in ("com.provenance.savestate", "com.provenance.cheat", "com.provenance.artwork"):
            self.assertIn(ident, exported)
        imported = _entries(self.info, gen.IMPORTED_KEY)
        self.assertIn("public.zip-archive", imported)
        self.assertIn("com.rileytestut.delta.skin", imported)

    def test_document_types_merge_by_name(self):
        self.run_main("--update-plist", str(self.info))
        docs = {d["CFBundleTypeName"]: d for d in plistlib.loads(self.info.read_bytes())[gen.DOCTYPES_KEY]}
        self.assertEqual(docs["Log File"]["LSItemContentTypes"], ["public.log"])
        rom = docs["ROM"]["LSItemContentTypes"]
        self.assertEqual(rom[:2], ["com.provenance.rom.nes", "com.provenance.rom"])  # existing order kept
        self.assertIn("public.zip-archive", rom)  # missing generator entries appended
        self.assertIn("Save State", docs)
        self.assertIn("Artwork", docs)

    def test_missing_and_empty_arrays_are_created(self):
        minimal = ('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n<dict>\n'
                   '\t<key>UTExportedTypeDeclarations</key>\n\t<array/>\n</dict>\n</plist>\n')
        self.info.write_text(minimal, encoding="utf-8")
        code, _ = self.run_main("--update-plist", str(self.info))
        self.assertEqual(code, 0)
        self.assertIn("com.provenance.rom.nes", _ids(self.info, gen.EXPORTED_KEY))
        self.assertIn("public.zip-archive", _ids(self.info, gen.IMPORTED_KEY))
        names = [d["CFBundleTypeName"] for d in plistlib.loads(self.info.read_bytes())[gen.DOCTYPES_KEY]]
        self.assertEqual(names, ["ROM", "Save State", "Artwork"])
        code, _ = self.run_main("--check", "--update-plist", str(self.info))
        self.assertEqual(code, 0)

    def test_stale_system_types_are_reported_only_with_prune_and_never_deleted(self):
        _, quiet = self.run_main("--update-plist", str(self.info))
        self.assertNotIn("stale", quiet)
        self.info.write_text(INFO_PLIST, encoding="utf-8")
        _, loud = self.run_main("--update-plist", str(self.info), "--prune")
        self.assertIn("stale com.provenance.rom.retired", loud)
        self.assertIn("com.provenance.rom.retired", _ids(self.info, gen.EXPORTED_KEY))


class IdempotenceTests(UtiMergeTestCase):
    def test_second_run_changes_nothing(self):
        self.run_main("--update-plist", str(self.info))
        first = self.info.read_bytes()
        code, out = self.run_main("--update-plist", str(self.info))
        self.assertEqual(code, 0)
        self.assertEqual(self.info.read_bytes(), first)
        self.assertIn("Unchanged", out)


class CheckModeTests(UtiMergeTestCase):
    def test_exit_1_and_names_the_plist_when_stale_and_writes_nothing(self):
        code, out = self.run_main("--check", "--update-plist", str(self.info))
        self.assertEqual(code, 1)
        self.assertIn(str(self.info), out)
        self.assertEqual(self.info.read_text(encoding="utf-8"), INFO_PLIST)

    def test_exit_0_when_current(self):
        self.run_main("--update-plist", str(self.info))
        code, _ = self.run_main("--check", "--update-plist", str(self.info))
        self.assertEqual(code, 0)

    def test_any_stale_plist_fails_the_whole_check(self):
        current = self.dir / "Current.plist"
        current.write_text(INFO_PLIST, encoding="utf-8")
        self.run_main("--update-plist", str(current))
        code, out = self.run_main("--check", "--update-plist", str(current), str(self.info))
        self.assertEqual(code, 1)
        self.assertIn("1 of 2", out)

    def test_missing_plist_is_an_error_not_a_pass(self):
        code, _ = self.run_main("--check", "--update-plist", str(self.dir / "nope.plist"))
        self.assertEqual(code, 2)

    def test_check_requires_plists(self):
        code, _ = self.run_main("--check")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
