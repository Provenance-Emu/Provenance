#!/usr/bin/env python3
"""Unit tests for prune_dead_project_refs (dead sub-project references in a pbxproj)."""

import importlib.util
import re
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "dev" / "prune_dead_project_refs.py"
_spec = importlib.util.spec_from_file_location("prune_dead_project_refs", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)

_HEX = {"F": "F0", "C": "C0", "G": "A0", "P": "B0", "R": "E0", "J": "D0"}


def I(tag: str) -> str:
    """24-hex object id for a readable 4-char fixture tag such as FR02."""
    return (_HEX[tag[0]] + tag[2:]).ljust(24, "0")

# Two sub-project refs: Live.xcodeproj (exists under Sub/, used by a container
# proxy) and Dead.xcodeproj (missing). Each has a projectReferences entry and a
# Products group; the dead one's Products group is empty.
_RAW = """// !$*UTF8*$!
{
	objects = {
		FR01 /* Live.xcodeproj */ = {isa = PBXFileReference; lastKnownFileType = "wrapper.pb-project"; name = Live.xcodeproj; path = Live.xcodeproj; sourceTree = "<group>"; };
		FR02 /* Dead.xcodeproj */ = {isa = PBXFileReference; lastKnownFileType = "wrapper.pb-project"; path = Dead.xcodeproj; sourceTree = "<group>"; };
		FR03 /* A.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = A.swift; sourceTree = "<group>"; };
		CP01 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = FR01 /* Live.xcodeproj */;
			proxyType = 2;
		};
		GR00 /* Root */ = {
			isa = PBXGroup;
			children = (
				GR01 /* Sub */,
				FR02 /* Dead.xcodeproj */,
				FR03 /* A.swift */,
			);
			sourceTree = "<group>";
		};
		GR01 /* Sub */ = {
			isa = PBXGroup;
			children = (
				FR01 /* Live.xcodeproj */,
			);
			path = Sub;
			sourceTree = "<group>";
		};
		PG01 /* Products */ = {
			isa = PBXGroup;
			children = (
				RP01 /* Live.framework */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		PG02 /* Products */ = {
			isa = PBXGroup;
			children = (
			);
			name = Products;
			sourceTree = "<group>";
		};
		PJ01 /* Project object */ = {
			isa = PBXProject;
			projectReferences = (
				{
					ProductGroup = PG01 /* Products */;
					ProjectRef = FR01 /* Live.xcodeproj */;
				},
				{
					ProductGroup = PG02 /* Products */;
					ProjectRef = FR02 /* Dead.xcodeproj */;
				},
			);
		};
	};
}
"""
PBXPROJ = re.sub(r"\b([A-Z]{2}\d{2})\b", lambda m: I(m.group(1)), _RAW)


class PruneDeadProjectRefsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "Sub" / "Live.xcodeproj").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_finds_only_missing_unreferenced_projects(self):
        dead = _mod.find_dead(PBXPROJ, self.root)
        self.assertEqual([(d[0], d[1]) for d in dead], [(I("FR02"), "Dead.xcodeproj")])

    def test_live_project_resolves_through_group_path(self):
        parent, comp = _mod.group_paths(PBXPROJ)
        self.assertEqual(_mod.resolve(I("FR01"), "Live.xcodeproj", parent, comp, self.root),
                         self.root / "Sub" / "Live.xcodeproj")

    def test_prune_removes_closure_and_nothing_else(self):
        out, counts = _mod.prune(PBXPROJ, {I("FR02")})
        self.assertEqual(counts, {"fileRefs": 1, "projectReferences": 1, "productGroups": 1, "childLines": 1})
        self.assertNotIn(I("FR02"), out)
        self.assertNotIn(I("PG02"), out)
        for keep in ("FR01", "FR03", "PG01", "RP01", "CP01", "GR01"):
            self.assertIn(I(keep), out)
        self.assertIn("ProjectRef = " + I("FR01"), out)

    def test_refuses_product_group_with_children(self):
        text = PBXPROJ.replace("ProjectRef = " + I("FR01"), "ProjectRef = " + I("FR09")).replace("ProjectRef = " + I("FR02"), "ProjectRef = " + I("FR01"))
        # Now FR01's entry carries PG02 (empty) and FR09's carries PG01 (non-empty): pruning FR09 must refuse.
        with self.assertRaises(SystemExit):
            _mod.prune(text, {I("FR09")})

    def test_referenced_missing_project_is_kept(self):
        text = PBXPROJ.replace("containerPortal = " + I("FR01"), "containerPortal = " + I("FR02"))
        self.assertEqual([d[0] for d in _mod.find_dead(text, self.root)], [])


if __name__ == "__main__":
    unittest.main()
