#!/usr/bin/env python3
"""Unit tests for Scripts/cores/build_slice.py (stdlib unittest; no git, Xcode or network)."""
from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_slice  # noqa: E402


def write(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class FakeRunner:
    """Stands in for git / xcodebuild / xcrun."""

    def __init__(self, head="aaaa", status=" bbbb externals/x (v1)\n-cccc externals/y", xcode="Xcode 26.3\nBuild version 17C1", sdk="26.2"):
        self.head, self.status, self.xcode, self.sdk = head, status, xcode, sdk
        self.dirty = {}  # repo path -> (porcelain, diff)

    def __call__(self, cmd, cwd=None):
        if cmd[-2:] == ["rev-parse", "HEAD"]:
            return self.head
        if cmd[:1] == ["git"] and "status" in cmd and "--porcelain=v1" in cmd:
            return self.dirty.get(cmd[2], ("", ""))[0]
        if cmd[:1] == ["git"] and "diff" in cmd:
            return self.dirty.get(cmd[2], ("", ""))[1]
        if "submodule" in cmd:
            return self.status
        if cmd[:2] == ["xcodebuild", "-version"]:
            return self.xcode
        if cmd[0] == "xcrun":
            return self.sdk
        raise AssertionError(f"unexpected command {cmd}")


class FakeRepo:
    def __init__(self, root: Path):
        self.root = root
        write(root / "Cores/Azahar/build_azahar_core.py", "CMAKE_OPTIONS = ['-DENABLE_LTO=OFF']\n")
        write(root / "Cores/Azahar/cmake/ios.toolchain.cmake", "toolchain v1\n")
        (root / "Cores/Azahar/azahar").mkdir(parents=True)
        for mvk in ("ios-arm64", "ios-arm64_x86_64-simulator", "tvos-arm64_arm64e", "tvos-arm64_x86_64-simulator"):
            write(root / f"MoltenVK/MoltenVK/static/MoltenVK.xcframework/{mvk}/libMoltenVK.a", f"mvk {mvk}\n")
        write(root / "Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py", "# dolphin\n")
        write(root / "Cores/Dolphin/dolphin-ios/Externals/ios-cmake/ios.toolchain.cmake", "dolphin toolchain\n")
        self.specs = build_slice.core_specs(root)


class KeyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = FakeRepo(Path(self.tmp.name))
        self.azahar = self.repo.specs["azahar"]
        self.dolphin = self.repo.specs["dolphin"]

    def tearDown(self):
        self.tmp.cleanup()

    def key(self, spec=None, slice_name="ios-sim", runner=None, env=None):
        return build_slice.compute_key(spec or self.azahar, slice_name, runner or FakeRunner(), env or {})

    def test_stable(self):
        self.assertEqual(self.key(), self.key())

    def test_changes_with_submodule_head(self):
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(head="dddd")))

    def test_changes_with_nested_submodule(self):
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(status=" eeee externals/x (v2)")))

    def test_submodule_init_state_does_not_change_key(self):
        a = FakeRunner(status=" bbbb externals/x (v1)")
        b = FakeRunner(status="-bbbb externals/x")
        self.assertEqual(self.key(runner=a), self.key(runner=b))

    def test_changes_with_script_and_toolchain(self):
        before = self.key()
        write(self.repo.root / "Cores/Azahar/build_azahar_core.py", "CMAKE_OPTIONS = ['-DENABLE_LTO=ON']\n")
        after_script = self.key()
        write(self.repo.root / "Cores/Azahar/cmake/ios.toolchain.cmake", "toolchain v2\n")
        self.assertNotEqual(before, after_script)
        self.assertNotEqual(after_script, self.key())

    def test_changes_with_xcode_and_sdk(self):
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(xcode="Xcode 26.4")))
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(sdk="26.4")))

    def test_changes_with_moltenvk_slice(self):
        before = self.key()
        write(self.repo.root / "MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64_x86_64-simulator/libMoltenVK.a", "new\n")
        self.assertNotEqual(before, self.key())

    def test_slices_differ(self):
        self.assertNotEqual(self.key(slice_name="ios"), self.key(slice_name="ios-sim"))

    def test_dolphin_flags_and_profile(self):
        base = self.key(self.dolphin)
        self.assertNotEqual(base, self.key(self.dolphin, env={"DOL_FULL_LTO": "1"}))
        profile = write(self.repo.root / "Cores/Dolphin/dolphin-ios/pgo/icube.profdata", "profile v1")
        with_profile = self.key(self.dolphin)
        self.assertNotEqual(base, with_profile)
        profile.write_text("profile v2")
        v2 = self.key(self.dolphin)
        self.assertNotEqual(with_profile, v2)
        self.assertEqual(base, self.key(self.dolphin, env={"DOL_PGO": "off"}))
        self.assertEqual(v2, self.key(self.dolphin, env={"DOL_PGO": "auto"}))
        self.assertEqual(v2, self.key(self.dolphin, env={"DOL_PGO": "use"}))

    def test_lto_is_boolean(self):
        base = self.key(self.dolphin)
        self.assertEqual(base, self.key(self.dolphin, env={"DOL_FULL_LTO": "0"}))
        self.assertEqual(base, self.key(self.dolphin, env={"DOL_FULL_LTO": "yes"}))
        self.assertNotEqual(base, self.key(self.dolphin, env={"DOL_FULL_LTO": "1"}))

    def test_pgo_profile_only_counts_when_selected(self):
        other = write(self.repo.root / "custom.profdata", "x")
        base = self.key(self.dolphin)
        self.assertEqual(base, self.key(self.dolphin, env={"DOL_PGO_PROFILE": str(other)}))
        self.assertNotEqual(base, self.key(self.dolphin, env={"DOL_PGO": "use", "DOL_PGO_PROFILE": str(other)}))

    def test_dirty_tree_changes_key_and_revert_restores(self):
        clean = self.key()
        sub = str(self.azahar.submodule)
        runner = FakeRunner()
        runner.dirty[sub] = (" M src/a.cpp", "diff --git a/src/a.cpp\n+x")
        dirty = self.key(runner=runner)
        self.assertNotEqual(clean, dirty)
        runner.dirty[sub] = (" M src/a.cpp", "diff --git a/src/a.cpp\n+y")
        self.assertNotEqual(dirty, self.key(runner=runner))
        runner.dirty.clear()
        self.assertEqual(clean, self.key(runner=runner))

    def test_nested_dirty_tree_changes_key(self):
        nested = str(self.azahar.submodule / "externals/x")
        runner = FakeRunner()
        runner.dirty[nested] = (" M a.c", "+1")
        self.assertNotEqual(self.key(), self.key(runner=runner))

    def test_untracked_file_contents_change_key(self):
        runner = FakeRunner()
        sub = self.azahar.submodule
        runner.dirty[str(sub)] = ("?? new.cpp", "")
        write(sub / "new.cpp", "one")
        first = self.key(runner=runner)
        write(sub / "new.cpp", "two")
        self.assertNotEqual(first, self.key(runner=runner))


class XCFrameworkTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = FakeRepo(Path(self.tmp.name))
        self.dolphin = self.repo.specs["dolphin"]
        self.azahar = self.repo.specs["azahar"]

    def tearDown(self):
        self.tmp.cleanup()

    def write_xcframework(self, spec, slices):
        import plistlib
        path = spec.legacy_dir / f"{spec.product}.xcframework" / "Info.plist"
        path.parent.mkdir(parents=True, exist_ok=True)
        libs = [{"LibraryPath": f"{spec.product}-{s}.framework"} for s in slices]
        path.write_bytes(plistlib.dumps({"AvailableLibraries": libs}))

    def test_dolphin_missing_xcframework_repacks(self):
        self.assertTrue(build_slice.needs_xcframework(self.dolphin, "ios", False, False))

    def test_dolphin_hit_with_slice_present_does_not_repack(self):
        self.write_xcframework(self.dolphin, ["ios", "ios-sim"])
        self.assertFalse(build_slice.needs_xcframework(self.dolphin, "ios", False, False))

    def test_dolphin_hit_missing_this_slice_repacks(self):
        self.write_xcframework(self.dolphin, ["ios-sim"])
        self.assertTrue(build_slice.needs_xcframework(self.dolphin, "ios", False, False))

    def test_dolphin_produced_slice_always_repacks(self):
        self.write_xcframework(self.dolphin, ["ios"])
        self.assertTrue(build_slice.needs_xcframework(self.dolphin, "ios", True, False))

    def test_azahar_only_when_requested(self):
        self.assertFalse(build_slice.needs_xcframework(self.azahar, "ios", True, False))
        self.assertTrue(build_slice.needs_xcframework(self.azahar, "ios", False, True))


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.repo = FakeRepo(root / "repo")
        self.cache = root / "cache"
        self.spec = self.repo.specs["azahar"]
        self.legacy = self.spec.legacy_dir / "PVlibAzahar-ios-sim.framework"

    def tearDown(self):
        self.tmp.cleanup()

    def fake_build(self, calls):
        def builder(spec, slice_name):
            calls.append(slice_name)
            assert not self.legacy.exists() and not self.legacy.is_symlink(), "legacy path must be cleared before building"
            write(self.legacy / "PVlibAzahar", "archive")
        return builder

    def test_miss_builds_moves_and_links(self):
        calls = []
        fw = build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {"a": "b"}, False, self.fake_build(calls))
        self.assertEqual(calls, ["ios-sim"])
        self.assertEqual(fw, self.cache / "azahar/ios-sim" / ("k" * 12) / "PVlibAzahar-ios-sim.framework")
        self.assertTrue((fw / "PVlibAzahar").is_file())
        self.assertTrue(self.legacy.is_symlink())
        self.assertEqual(Path(os.readlink(self.legacy)), fw)
        stamp = json.loads((fw.parent / "stamp.json").read_text())
        self.assertEqual(stamp["key"], "k" * 64)
        self.assertEqual(stamp["inputs"], {"a": "b"})

    def test_hit_only_links(self):
        calls = []
        build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, self.fake_build(calls))
        self.legacy.unlink()
        write(self.legacy / "PVlibAzahar", "stale real dir from an old build")

        def must_not_build(spec, slice_name):
            raise AssertionError("cache hit must not build")

        fw = build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, must_not_build)
        self.assertTrue(self.legacy.is_symlink())
        self.assertEqual(Path(os.readlink(self.legacy)), fw)

    def test_force_rebuilds_over_existing_symlink(self):
        calls = []
        build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, self.fake_build(calls))
        build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, True, self.fake_build(calls))
        self.assertEqual(calls, ["ios-sim", "ios-sim"])
        self.assertTrue(self.legacy.is_symlink())

    def test_old_entries_pruned(self):
        calls = []
        for key in ("a" * 64, "b" * 64, "c" * 64):
            build_slice.ensure_slice(self.spec, "ios-sim", self.cache, key, {}, False, self.fake_build(calls))
        entries = sorted(p.name for p in (self.cache / "azahar/ios-sim").iterdir())
        self.assertEqual(len(entries), build_slice.KEEP_ENTRIES)
        self.assertIn("c" * 12, entries)

    def test_missing_product_fails(self):
        with self.assertRaises(SystemExit):
            build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, lambda spec, s: None)


class CLITests(unittest.TestCase):
    def test_print_key_matches_compute_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = FakeRepo(Path(tmp))
            runner = FakeRunner()
            out = io.StringIO()
            with redirect_stdout(out):
                code = build_slice.main(["azahar", "tvos", "--print-key", "--repo-root", tmp], runner=runner, env={})
            self.assertEqual(code, 0)
            self.assertEqual(out.getvalue().strip(), build_slice.compute_key(repo.specs["azahar"], "tvos", runner, {}))

    def test_slice_from_platform_name(self):
        self.assertEqual(build_slice.SLICE_FOR_PLATFORM_NAME["appletvsimulator"], "tvos-sim")
        self.assertEqual(build_slice.SLICE_FOR_PLATFORM_NAME["iphoneos"], "ios")


if __name__ == "__main__":
    unittest.main()
