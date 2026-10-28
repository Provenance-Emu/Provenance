#!/usr/bin/env python3
"""Guard Top Shelf's modern extension registration, independent of its data path.

Run: python3 -m unittest discover -s Scripts/tests -p test_topshelf_registration.py
The legacy tv-app-extension type selects _TVExtensionMain, which expects the
TVTopShelfProvider protocol rather than a TVTopShelfContentProvider subclass.
"""

import importlib.util
from pathlib import Path
import plistlib
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "check_pbxproj_sources", ROOT / "Scripts/audits/check_pbxproj_sources.py"
)
PARSER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PARSER)


class TopShelfRegistrationTests(unittest.TestCase):
    def test_provider_uses_standard_extension_entry_point(self):
        project, _ = PARSER.parse(list(PARSER.tokenize(
            (ROOT / "Provenance.xcodeproj/project.pbxproj").read_text()
        )))
        targets = [obj for obj in project["objects"].values()
                   if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == "TopShelf"]
        self.assertEqual(len(targets), 1)
        self.assertEqual(
            targets[0]["productType"], "com.apple.product-type.app-extension",
            "TVTopShelfContentProvider needs _NSExtensionMain; tv-app-extension selects _TVExtensionMain",
        )

    def test_registration_does_not_request_legacy_provider_protocol(self):
        with (ROOT / "Extensions/TopShelf/Info.plist").open("rb") as file:
            extension = plistlib.load(file)["NSExtension"]
        self.assertEqual(extension["NSExtensionPointIdentifier"], "com.apple.tv-top-shelf")
        protocols = extension.get("NSExtensionAttributes", {}).get("TVExtensionProtocols", [])
        self.assertNotIn(
            "TVTopShelfProvider", protocols,
            "The modern provider subclasses TVTopShelfContentProvider and does not implement the legacy protocol",
        )


if __name__ == "__main__":
    unittest.main()
