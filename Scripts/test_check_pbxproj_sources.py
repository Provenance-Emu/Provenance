#!/usr/bin/env python3
"""Unit tests for check_pbxproj_sources (unreferenced Xcode sources)."""

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "check_pbxproj_sources.py"
_spec = importlib.util.spec_from_file_location("check_pbxproj_sources", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)
check_project = _mod.check_project
index_sources = _mod.index_sources
parse = _mod.parse
tokenize = _mod.tokenize

# Mod/Mod.xcodeproj compiling Mod/Sources/A.swift. The main group's child
# "Sources" is a <group>-relative folder; B.swift sits beside A.swift but is
# only referenced (not compiled); Synced/ is a synchronized root group.
PBXPROJ = """// !$*UTF8*$!
{
	archiveVersion = 1;
	objects = {
		BF01 /* A.swift in Sources */ = {isa = PBXBuildFile; fileRef = FR01 /* A.swift */; };
		FR01 /* A.swift */ = {isa = PBXFileReference; path = A.swift; sourceTree = "<group>"; };
		FR02 /* B.swift */ = {isa = PBXFileReference; path = "B.swift"; sourceTree = "<group>"; };
		GR00 = {isa = PBXGroup; children = (GR01, SY01, ); sourceTree = "<group>"; };
		GR01 /* Sources */ = {isa = PBXGroup; children = (FR01, FR02, ); path = Sources; sourceTree = "<group>"; };
		SY01 /* Synced */ = {isa = PBXFileSystemSynchronizedRootGroup; path = Sources/Synced; sourceTree = "<group>"; };
		PH01 = {isa = PBXSourcesBuildPhase; files = (BF01 /* A.swift in Sources */, ); };
		PR01 = {isa = PBXProject; mainGroup = GR00; };
	};
	rootObject = PR01;
}
"""


class CheckProjectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.pbxproj = os.path.join(self.tmp.name, "Mod", "Mod.xcodeproj", "project.pbxproj")
        os.makedirs(os.path.dirname(self.pbxproj))
        with open(self.pbxproj, "w", encoding="utf-8") as fh:
            fh.write(PBXPROJ)
        self.src = os.path.join(self.tmp.name, "Mod", "Sources")

    def missing(self, *names):
        return check_project(self.pbxproj, index_sources(os.path.join(self.src, n) for n in names))

    def test_new_file_beside_compiled_sources_is_flagged(self):
        self.assertEqual(self.missing("A.swift", "New.swift"), [os.path.join(self.src, "New.swift")])

    def test_referenced_files_pass_even_when_not_compiled(self):
        self.assertEqual(self.missing("A.swift", "B.swift"), [])

    def test_synchronized_group_covers_its_files(self):
        self.assertEqual(self.missing("A.swift", "Synced/C.swift"), [])

    def test_directories_without_compiled_sources_are_ignored(self):
        self.assertEqual(self.missing("A.swift", "Other/D.swift"), [])

    def test_non_source_files_and_manifests_are_ignored(self):
        self.assertEqual(self.missing("A.swift", "README.md", "Package.swift"), [])


class ProjectDirPathTests(unittest.TestCase):
    def test_project_dir_path_moves_the_source_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            pbxproj = os.path.join(tmp, "build", "Mod.xcodeproj", "project.pbxproj")
            os.makedirs(os.path.dirname(pbxproj))
            with open(pbxproj, "w", encoding="utf-8") as fh:
                fh.write(PBXPROJ.replace("mainGroup = GR00;", 'mainGroup = GR00; projectDirPath = "../Mod";'))
            src = os.path.join(tmp, "Mod", "Sources")
            files = index_sources(os.path.join(src, n) for n in ("A.swift", "New.swift"))
            self.assertEqual(check_project(pbxproj, files), [os.path.join(src, "New.swift")])


class ParseTests(unittest.TestCase):
    def test_quoted_strings_comments_and_trailing_commas(self):
        value, _ = parse(list(tokenize('{ a = "x \\"y\\""; /* c */ b = (1, 2, ); // d\n}')))
        self.assertEqual(value, {"a": 'x "y"', "b": ["1", "2"]})


if __name__ == "__main__":
    unittest.main()
