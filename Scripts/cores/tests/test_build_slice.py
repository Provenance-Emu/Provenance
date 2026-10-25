#!/usr/bin/env python3
"""Unit tests for Scripts/cores/build_slice.py (stdlib unittest; no git, Xcode or network)."""
from __future__ import annotations

import io
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

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
        self.trees = {}  # path in HEAD -> object id (default "tree-<path>")
        self.tree = "160000 commit bbbb\texternals/x\n100644 blob dddd\tsrc/main.cpp"
        self.scans = 0  # working-tree scans (git status --porcelain)

    def __call__(self, cmd, cwd=None):
        if cmd[-2:] == ["rev-parse", "HEAD"]:
            return self.head
        if "rev-parse" in cmd:
            paths = [arg[len("HEAD:"):] for arg in cmd if arg.startswith("HEAD:")]
            return "\n".join(self.trees.get(path, f"tree-{path}") for path in paths)
        if "ls-tree" in cmd:
            return self.tree
        if cmd[:1] == ["git"] and "status" in cmd and "--porcelain=v1" in cmd:
            self.scans += 1
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


    def test_untracked_docs_do_not_change_key(self):
        runner = FakeRunner()
        sub = self.azahar.submodule
        runner.dirty[str(sub)] = ("?? docs/superpowers/baselines/shot.png\n?? notes.md", "")
        write(sub / "docs/superpowers/baselines/shot.png", "png")
        write(sub / "notes.md", "notes")
        self.assertEqual(self.key(), self.key(runner=runner))

    def test_edited_markdown_does_not_change_key(self):
        runner = FakeRunner()
        runner.dirty[str(self.azahar.submodule)] = (
            " M README.md\n M docs/plan.txt",
            "diff --git a/README.md b/README.md\n+x\ndiff --git a/docs/plan.txt b/docs/plan.txt\n+y\n")
        self.assertEqual(self.key(), self.key(runner=runner))

    def test_docs_ignored_but_source_edits_still_count(self):
        sub = str(self.azahar.submodule)
        source_only = FakeRunner()
        source_only.dirty[sub] = (" M src/a.cpp", "diff --git a/src/a.cpp b/src/a.cpp\n+x\n")
        mixed = FakeRunner()
        mixed.dirty[sub] = (" M README.md\n M src/a.cpp",
                            "diff --git a/README.md b/README.md\n+doc\ndiff --git a/src/a.cpp b/src/a.cpp\n+x\n")
        self.assertNotEqual(self.key(), self.key(runner=source_only))
        self.assertEqual(self.key(runner=source_only), self.key(runner=mixed))

    def test_dolphin_app_commit_does_not_change_key(self):
        # An iCube commit that touches only app code moves HEAD but none of the build trees.
        self.assertEqual(self.key(self.dolphin), self.key(self.dolphin, runner=FakeRunner(head="ffff")))

    def test_dolphin_engine_commit_changes_key(self):
        for path in build_slice.DOLPHIN_BUILD_PATHS:
            runner = FakeRunner()
            runner.trees[path] = "changed"
            self.assertNotEqual(self.key(self.dolphin), self.key(self.dolphin, runner=runner), path)

    def test_dolphin_app_edits_do_not_change_key(self):
        runner = FakeRunner()
        runner.dirty[str(self.dolphin.submodule)] = (
            " M Source/iOS/App/iCube/Views/Library.swift\n M build/xcframework/PVlibDolphin-ios.framework/PVlibDolphin-ios\n"
            "?? Source/iOS/PVLibrary/New.swift\n M CMakePresets.json\n M Data/Sys/GameSettings/GALE01.ini",
            "diff --git a/Source/iOS/App/iCube/Views/Library.swift b/Source/iOS/App/iCube/Views/Library.swift\n+x\n"
            "diff --git a/CMakePresets.json b/CMakePresets.json\n+y\n")
        self.assertEqual(self.key(self.dolphin), self.key(self.dolphin, runner=runner))

    def test_dolphin_engine_edits_change_key(self):
        for path in ("Source/Core/Core/Core.cpp", "Source/iOS/Library/Host.mm", "CMake/CCache.cmake",
                     "CMakeLists.txt", "Data/Sys/ApprovedInis.json"):
            runner = FakeRunner()
            runner.dirty[str(self.dolphin.submodule)] = (f" M {path}", f"diff --git a/{path} b/{path}\n+x\n")
            self.assertNotEqual(self.key(self.dolphin), self.key(self.dolphin, runner=runner), path)

    def test_dolphin_scan_is_limited_to_build_paths(self):
        calls = []
        runner = FakeRunner()

        def recording(cmd, cwd=None):
            calls.append(cmd)
            return runner(cmd, cwd)

        self.key(self.dolphin, runner=recording)
        top = str(self.dolphin.submodule)
        scans = [cmd for cmd in calls if cmd[:3] == ["git", "-C", top] and ("status" in cmd or "diff" in cmd)
                 and "submodule" not in cmd]
        self.assertEqual(len(scans), 2)
        for cmd in scans:
            self.assertEqual(cmd[cmd.index("--") + 1:], list(build_slice.DOLPHIN_BUILD_PATHS))

    def test_rename_out_of_build_paths_counts(self):
        runner = FakeRunner()
        runner.dirty[str(self.dolphin.submodule)] = ("R  Source/Core/a.cpp -> Source/iOS/App/a.cpp", "")
        self.assertNotEqual(self.key(self.dolphin), self.key(self.dolphin, runner=runner))

    def test_missing_build_path_fails_loudly(self):
        import subprocess

        def runner(cmd, cwd=None):
            if "rev-parse" in cmd and any(arg.startswith("HEAD:") for arg in cmd):
                raise subprocess.CalledProcessError(128, cmd)
            return FakeRunner()(cmd, cwd)

        with self.assertRaises(SystemExit):
            self.key(self.dolphin, runner=runner)


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

    def test_azahar_slice_found_by_platform(self):
        import plistlib
        path = self.azahar.legacy_dir / "PVlibAzahar.xcframework" / "Info.plist"
        path.parent.mkdir(parents=True, exist_ok=True)
        libs = [{"LibraryPath": "PVlibAzahar.framework", "SupportedPlatform": "ios"},
                {"LibraryPath": "PVlibAzahar.framework", "SupportedPlatform": "tvos", "SupportedPlatformVariant": "simulator"}]
        path.write_bytes(plistlib.dumps({"AvailableLibraries": libs}))
        self.assertTrue(build_slice.xcframework_has_slice(self.azahar, "ios"))
        self.assertTrue(build_slice.xcframework_has_slice(self.azahar, "tvos-sim"))
        self.assertFalse(build_slice.xcframework_has_slice(self.azahar, "ios-sim"))
        self.assertFalse(build_slice.xcframework_has_slice(self.azahar, "tvos"))

    def test_azahar_only_when_requested(self):
        self.assertFalse(build_slice.needs_xcframework(self.azahar, "ios", True, False))
        self.assertTrue(build_slice.needs_xcframework(self.azahar, "ios", False, True))


class HeaderTests(unittest.TestCase):
    def test_prepared_headers_follow_the_selected_slice(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = FakeRepo(Path(tmp))
            spec = repo.specs["azahar"]
            ios = write(spec.legacy_dir / "PVlibAzahar-ios.framework/Headers/config.h", "ios")
            tvos = write(spec.legacy_dir / "PVlibAzahar-tvos.framework/Headers/config.h", "tvos")
            build_slice.prepare_headers(spec, ios.parent.parent)
            headers = spec.legacy_dir.parent / "headers"
            self.assertEqual((headers / "config.h").read_text(), "ios")
            build_slice.prepare_headers(spec, tvos.parent.parent)
            self.assertEqual((headers / "config.h").read_text(), "tvos")

    def test_missing_headers_fail_before_package_resolution(self):
        with tempfile.TemporaryDirectory() as tmp:
            spec = FakeRepo(Path(tmp)).specs["azahar"]
            with self.assertRaises(SystemExit):
                build_slice.prepare_headers(spec, spec.legacy_dir / "missing.framework")


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


class FastPathTests(unittest.TestCase):
    """A repeat preparation must not rescan the working trees unless something cheap changed."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.repo_root = root / "repo"
        self.repo = FakeRepo(self.repo_root)
        self.cache = root / "cache"
        self.runner = FakeRunner()
        self.builds = []
        self.packs = []
        self._pack = build_slice.pack_xcframework
        build_slice.pack_xcframework = lambda spec: self.packs.append(spec.name)

    def tearDown(self):
        build_slice.pack_xcframework = self._pack
        self.tmp.cleanup()

    def builder(self, spec, slice_name):
        self.builds.append(slice_name)
        write(spec.legacy_dir / f"{spec.product}-{slice_name}.framework/Headers/config.h", "h")

    def prepare(self, *extra, env=None, core="azahar"):
        args = [core, "ios", "--repo-root", str(self.repo_root), "--cache-dir", str(self.cache), *extra]
        return build_slice.main(args, runner=self.runner, env=env or {}, builder=self.builder)

    def test_second_run_skips_the_scan(self):
        self.prepare()
        scans = self.runner.scans
        self.assertGreater(scans, 0)
        self.prepare()
        self.assertEqual(self.runner.scans, scans)
        self.assertEqual(self.builds, ["ios"])

    def test_strict_flag_and_env_rescan(self):
        self.prepare()
        scans = self.runner.scans
        self.prepare("--strict")
        self.assertGreater(self.runner.scans, scans)
        scans = self.runner.scans
        self.prepare(env={"PV_CORE_STRICT": "1"})
        self.assertGreater(self.runner.scans, scans)

    def test_cheap_input_change_rescans_and_rebuilds(self):
        self.prepare()
        scans = self.runner.scans
        self.runner.head = "ffff"
        self.prepare()
        self.assertGreater(self.runner.scans, scans)
        self.assertEqual(self.builds, ["ios", "ios"])

    def test_dolphin_app_commit_skips_scan_and_build(self):
        self.prepare(core="dolphin")
        scans = self.runner.scans
        self.runner.head = "ffff"
        self.prepare(core="dolphin")
        self.assertEqual(self.runner.scans, scans)
        self.assertEqual(self.builds, ["ios"])

    def test_dolphin_engine_commit_rescans_and_rebuilds(self):
        self.prepare(core="dolphin")
        scans = self.runner.scans
        self.runner.trees["Source/Core"] = "changed"
        self.prepare(core="dolphin")
        self.assertGreater(self.runner.scans, scans)
        self.assertEqual(self.builds, ["ios", "ios"])

    def test_nested_gitlink_change_rescans(self):
        self.prepare()
        scans = self.runner.scans
        self.runner.tree = "160000 commit eeee\texternals/x"
        self.prepare()
        self.assertGreater(self.runner.scans, scans)

    def test_evicted_cache_entry_rescans(self):
        self.prepare()
        scans = self.runner.scans
        for entry in (self.cache / "azahar/ios").iterdir():
            if entry.is_dir():
                import shutil
                shutil.rmtree(entry)
        self.prepare()
        self.assertGreater(self.runner.scans, scans)
        self.assertEqual(self.builds, ["ios", "ios"])

    def test_fast_path_uses_the_same_key_as_a_full_scan(self):
        self.prepare()
        record = json.loads(next((self.cache / "azahar/ios").glob("prepared-*.json")).read_text())
        spec = self.repo.specs["azahar"]
        self.assertEqual(record["key"], build_slice.compute_key(spec, "ios", self.runner, {}))

    def test_xcframework_packed_once_per_key(self):
        spec = self.repo.specs["azahar"]
        plist = spec.legacy_dir / "PVlibAzahar.xcframework/Info.plist"

        def pack(s):
            import plistlib
            self.packs.append(s.name)
            plist.parent.mkdir(parents=True, exist_ok=True)
            plist.write_bytes(plistlib.dumps({"AvailableLibraries": [{"LibraryPath": "PVlibAzahar-ios.framework"}]}))

        build_slice.pack_xcframework = pack
        self.prepare("--xcframework")
        self.prepare("--xcframework")
        self.assertEqual(self.packs, ["azahar"])
        plist.unlink()
        self.prepare("--xcframework")
        self.assertEqual(self.packs, ["azahar", "azahar"])


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


class AzaharCMakeCacheTests(unittest.TestCase):
    """Restored native build trees must belong to the current checkout."""

    @classmethod
    def setUpClass(cls):
        script = Path(__file__).resolve().parents[3] / "Cores/Azahar/build_azahar_core.py"
        spec = importlib.util.spec_from_file_location("azahar_cache_tests", script)
        cls.azahar = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.azahar)

    def test_configure_discards_relocated_or_incomplete_tree(self):
        for changed in ("CMAKE_HOME_DIRECTORY", "CMAKE_CACHEFILE_DIR", "missing"):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                source, out = root / "source", root / "build/TVOS"
                source.mkdir()
                out.mkdir(parents=True)
                entries = {"CMAKE_HOME_DIRECTORY": source, "CMAKE_CACHEFILE_DIR": out}
                if changed == "missing":
                    entries.clear()
                else:
                    entries[changed] = Path("/old/runner/checkout")
                write(out / "CMakeCache.txt", "".join(f"{key}:INTERNAL={value}\n" for key, value in entries.items()))
                write(out / "stale-object.a", "old")
                sibling = write(root / "build/OS64/keep.a", "other slice")
                mvk = root / "MoltenVK"
                write(mvk / self.azahar.PLATFORMS["TVOS"]["mvk"] / "libMoltenVK.a", "stub")
                builder = object.__new__(self.azahar.AzaharBuilder)
                builder.verbose = False

                def configured(cmd, cwd, verbose):
                    self.assertEqual(cwd, out)
                    self.assertTrue(out.is_dir())
                    self.assertFalse((out / "CMakeCache.txt").exists())
                    self.assertFalse((out / "stale-object.a").exists())
                    self.assertTrue(sibling.exists())

                with patch.object(self.azahar, "SRC", source), patch.object(self.azahar, "MOLTENVK_XCFW", mvk), \
                     patch.object(self.azahar, "run", side_effect=configured) as run:
                    builder.configure("TVOS", out)
                    run.assert_called_once()

    def test_compatible_tree_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, out = Path(tmp) / "source", Path(tmp) / "build/TVOS"
            source.mkdir()
            write(out / "CMakeCache.txt", f"CMAKE_HOME_DIRECTORY:INTERNAL={source}\nCMAKE_CACHEFILE_DIR:INTERNAL={out}\n")
            marker = write(out / "keep.a", "valid")
            with patch.object(self.azahar, "SRC", source):
                self.azahar.prepare_build_directory(out)
            self.assertEqual(marker.read_text(), "valid")


class RemoteTests(unittest.TestCase):
    """--remote: sync the build inputs to the host, build there, fetch the framework back."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.repo = FakeRepo(self.root)
        self.azahar = self.repo.specs["azahar"]
        self.dolphin = self.repo.specs["dolphin"]

    def tearDown(self):
        self.tmp.cleanup()

    def test_picks_first_reachable_default_host(self):
        tried = []
        host = build_slice.pick_remote_host(None, lambda h: tried.append(h) or h == "studio-runner")
        self.assertEqual(host, "studio-runner")
        self.assertEqual(tried, ["studio-cable", "studio-runner"])

    def test_named_host_is_the_only_candidate(self):
        self.assertEqual(build_slice.pick_remote_host("mini", lambda h: True), "mini")
        with self.assertRaises(SystemExit):
            build_slice.pick_remote_host("mini", lambda h: False)

    def test_unreachable_hosts_fail_instead_of_building_here(self):
        with self.assertRaises(SystemExit):
            build_slice.pick_remote_host(None, lambda h: False)

    def test_dolphin_syncs_only_build_paths(self):
        paths = build_slice.remote_sync_paths(self.dolphin, "ios", self.root)
        self.assertIn("Cores/Dolphin/dolphin-ios/Source/Core", paths)
        self.assertIn("Cores/Dolphin/dolphin-ios/Externals", paths)
        self.assertIn("Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py", paths)
        self.assertFalse(any(path.startswith("Cores/Dolphin/dolphin-ios/Source/iOS/App") for path in paths))
        self.assertFalse(any("/build" in path for path in paths))

    def test_azahar_syncs_its_moltenvk_slice_only(self):
        paths = build_slice.remote_sync_paths(self.azahar, "tvos", self.root)
        self.assertIn("Cores/Azahar/azahar", paths)
        self.assertIn("Cores/Azahar/build_azahar_core.py", paths)
        self.assertIn("MoltenVK/MoltenVK/static/MoltenVK.xcframework/tvos-arm64_arm64e", paths)
        self.assertNotIn("MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64", paths)

    def test_build_command_expands_home_on_the_host(self):
        command = build_slice.remote_build_command(self.dolphin, "ios", self.root, "$HOME/Builds/pv-slices/dolphin")
        self.assertIn('cd "$HOME/Builds/pv-slices/dolphin/Cores/Dolphin/dolphin-ios"', command)
        self.assertTrue(command.endswith(" OS64"))
        self.assertIn(build_slice.REMOTE_PYTHON, command)

    def test_builder_syncs_builds_and_fetches(self):
        calls = []
        builder = build_slice.make_remote_builder(None, self.root, probe=lambda h: h == "studio-runner",
                                                  run=lambda cmd, **kwargs: calls.append(cmd))
        with patch.object(build_slice, "default_runner", return_value="Xcode 27.1"):
            builder(self.dolphin, "ios")
        self.assertEqual(calls[0][0], "ssh")
        self.assertIn("mkdir -p", calls[0][-1])
        syncs = [cmd for cmd in calls if cmd[0] == "rsync" and cmd[-1].startswith("studio-runner:")]
        self.assertTrue(syncs)
        self.assertTrue(all("--exclude" in cmd and ".git" in cmd for cmd in syncs))
        build = [cmd for cmd in calls if cmd[0] == "ssh" and "-c" in cmd[-1]]
        self.assertEqual(len(build), 1)
        fetch = calls[-1]
        self.assertEqual(fetch[0], "rsync")
        self.assertTrue(fetch[-2].startswith("studio-runner:Builds/pv-slices/dolphin/"))
        self.assertTrue(fetch[-1].endswith("PVlibDolphin-ios.framework/"))

    def test_main_uses_remote_builder_from_environment(self):
        made = []

        def fake_make(preference, repo, **kwargs):
            made.append(preference)
            return lambda spec, slice_name: None

        with patch.object(build_slice, "make_remote_builder", side_effect=fake_make), \
             patch.object(build_slice, "ensure_slice", return_value=self.root / "fw"), \
             patch.object(build_slice, "prepare_headers"), patch.object(build_slice, "pack_xcframework"), \
             redirect_stdout(io.StringIO()):
            build_slice.main(["azahar", "ios", "--repo-root", str(self.root), "--cache-dir", str(self.root / "cache")],
                             runner=FakeRunner(), env={"PV_CORE_REMOTE": "mini"})
        self.assertEqual(made, ["mini"])


if __name__ == "__main__":
    unittest.main()
