"""Package cores must resolve their principal class and resources the SwiftPM way.

- The Swift target that owns Core.plist must be named like the PVPrincipleClass module prefix,
  or NSClassFromString returns nil and the core never instantiates (Mupen, 2026-10-12).
- In package builds a core's `resourceBundle` must be `Bundle.module`: resources sit in the
  <Package>_<Target>.bundle, not in the framework that `Bundle(for:)` returns.
"""
import json
import plistlib
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# core dir -> Core.plist path (relative to the core dir) of the package's Swift target
CORES = {
    "PPSSPP": "PVPPSSPP/Core.plist",
    "ep128emu": "PVEP128EmuCore/Resources/Core.plist",
    "snes9x": "PVSNES/Core.plist",
    "FCEU": "PVFCEU/Core.plist",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/Resources/Core.plist",
    "Mupen64Plus": "Sources/PVMupen/Resources/Core.plist",
    "Azahar": "PVAzahar/Core.plist",
    "Dolphin": "PVDolphin/Core.plist",
    "emuThree": "PVEmuThree/Core.plist",
}

# cores the shipping app takes from their packages -> their CorePlist.swift
SHIPPED_AS_PACKAGES = {
    "PPSSPP": "PVPPSSPPCore/Core/CorePlist.swift",
    "Dolphin": "PVDolphinCore/Core/CorePlist.swift",
    "emuThree": "PVEmuThreeCore/Core/CorePlist.swift",
    "ep128emu": "PVEP128EmuCore/CorePlist.swift",
    "snes9x": "PVSNES/SNES/CorePlist.swift",
    "FCEU": "CorePlist.swift",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/CorePlist.swift",
    "Mupen64Plus": "Sources/PVMupen/CorePlist.swift",
}


def dump_package(core: str) -> dict:
    out = subprocess.run(["swift", "package", "dump-package"], cwd=ROOT / "Cores" / core,
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out)


class ModuleNameTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_core_plist_owner_is_the_principal_class_module(self):
        for core, plist_rel in CORES.items():
            with self.subTest(core=core):
                plist = plistlib.loads((ROOT / "Cores" / core / plist_rel).read_bytes())
                module = plist["PVPrincipleClass"].split(".")[0]
                owners = []
                for target in dump_package(core)["targets"]:
                    base = target.get("path") or f"Sources/{target['name']}"
                    for resource in target.get("resources", []):
                        if str(Path(base) / resource["path"]) == plist_rel:
                            owners.append(target["name"])
                self.assertEqual(owners, [module])


def swift_package_branch(source: str) -> str:
    match = re.search(r"#if SWIFT_PACKAGE\n(.*?)\n#else", source, re.S)
    return match.group(1) if match else ""


class ResourceBundleTests(unittest.TestCase):
    def test_package_resource_bundle_is_bundle_module(self):
        for core, rel in SHIPPED_AS_PACKAGES.items():
            with self.subTest(core=core):
                source = (ROOT / "Cores" / core / rel).read_text()
                package_branch = swift_package_branch(source)
                accessor = re.search(r"override var resourceBundle: Bundle \{ ([^}]+?) \}", source)
                self.assertIsNotNone(accessor, "no resourceBundle override")
                expr = accessor.group(1).strip()
                if expr != "Bundle.module":
                    name = expr.split(".")[-1]
                    definition = re.search(rf"static var {name}: Bundle \{{ ([^}}]+?) \}}", package_branch)
                    self.assertIsNotNone(definition, f"{name} not defined under SWIFT_PACKAGE")
                    expr = definition.group(1).strip()
                self.assertEqual(expr, "Bundle.module")


class CorePackageLayoutTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_source_targets_are_libraries_with_separate_languages(self):
        for relative in ["PVCoreBridgeRetro", "Cores/ep128emu", "Cores/emuThree", "Cores/Dolphin", "Cores/PPSSPP"]:
            with self.subTest(package=relative):
                if relative == "Cores/Dolphin" and not (
                    ROOT / relative / "dolphin-ios/build/xcframework/PVlibDolphin.xcframework"
                ).is_dir():
                    self.skipTest("Dolphin source layout requires its prepared native binary")
                result = subprocess.run(
                    ["swift", "package", "describe", "--type", "json"], cwd=ROOT / relative,
                    check=True, capture_output=True, text=True,
                )
                description = json.loads(result.stdout)
                for target in description["targets"]:
                    if target["type"] in {"test", "binary"}:
                        continue
                    self.assertEqual(target["type"], "library", target["name"])
                    extensions = {Path(source).suffix for source in target.get("sources", [])}
                    self.assertFalse(".swift" in extensions and extensions & {".m", ".mm", ".c", ".cpp"}, target["name"])
                    base = ROOT / relative / target["path"]
                    for source in target.get("sources", []):
                        self.assertTrue((base / source).is_file(), source)


class PPSSPPPackageTests(unittest.TestCase):
    def test_bridge_resources_and_swift_runtime_lookup(self):
        core = ROOT / "Cores/PPSSPP"
        source = (core / "PVPPSSPPCore/Core/PVPPSSPPCore.mm").read_text()
        self.assertIn("SWIFTPM_MODULE_BUNDLE", source)
        self.assertNotIn("bundleForClass:", source)
        self.assertIn('stringByAppendingPathComponent:@"flash0"', source)
        self.assertTrue((core / "cmake/assets/flash0/font/ltn0.pgf").is_file())
        video = (core / "PVPPSSPPCore/Core/PVPPSSPPCore+Video.mm").read_text()
        for controller in ["PPSSPPVulkanViewController", "PPSSPPOGLViewController"]:
            self.assertIn(f"[PV_PPSSPP_SWIFT_CLASS({controller}) alloc]", video)
        interop = (core / "PVPPSSPPCore/Core/PPSSPPSwiftInterop.h").read_text()
        self.assertIn('NSClassFromString(@"PVPPSSPP." #name)', interop)

    @unittest.skipUnless(shutil.which("xcrun"), "Clang module validation requires Xcode")
    def test_native_modules_can_be_imported_together(self):
        module_map = ROOT / "Cores/PPSSPP/SwiftPM/include/module.modulemap"
        names = re.findall(r"^module (\w+)", module_map.read_text(), re.M)
        self.assertTrue(names, "native module map is empty")
        result = subprocess.run(
            ["xcrun", "clang", "-fmodules", "-x", "objective-c", "-fsyntax-only", "-",
             f"-fmodule-map-file={module_map}"],
            input="".join(f"@import {name};\n" for name in names),
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("xcrun"), "native digest validation requires Xcode")
    def test_ppsspp_and_cheevos_md5_link_and_hash_independently(self):
        with tempfile.TemporaryDirectory(prefix="ppsspp-md5-") as temporary:
            directory = Path(temporary)
            harness = directory / "main.cpp"
            harness.write_text("""
#include <cstring>
#include "Cores/PPSSPP/SwiftPM/Native/MD5Namespace.h"
#include "Cores/PPSSPP/libretro_ppsspp/Common/Crypto/md5.h"
#undef md5_finish
#include "PVRcheevos/rcheevos/src/rhash/md5.h"
int main() {
    unsigned char input[] = "abc";
    const unsigned char expected[16] = {0x90,0x01,0x50,0x98,0x3c,0xd2,0x4f,0xb0,0xd6,0x96,0x3f,0x7d,0x28,0xe1,0x7f,0x72};
    unsigned char psp[16], incremental[16], cheevos[16];
    md5(input, 3, psp);
    md5_context pspContext;
    md5_starts(&pspContext);
    md5_update(&pspContext, input, 3);
    PVPPSSPP_md5_finish(&pspContext, incremental);
    md5_state_t cheevosContext;
    md5_init(&cheevosContext);
    md5_append(&cheevosContext, input, 3);
    md5_finish(&cheevosContext, cheevos);
    return std::memcmp(psp, expected, 16) || std::memcmp(incremental, expected, 16) || std::memcmp(cheevos, expected, 16);
}
""")
            cheevos = directory / "cheevos.o"
            subprocess.run(["xcrun", "clang", "-c", str(ROOT / "PVRcheevos/rcheevos/src/rhash/md5.c"),
                            "-o", str(cheevos)], check=True, capture_output=True)
            executable = directory / "digest-test"
            subprocess.run(["xcrun", "clang++", "-std=c++17", "-I", str(ROOT), str(harness),
                            str(ROOT / "Cores/PPSSPP/SwiftPM/Native/MD5.cpp"), str(cheevos),
                            "-o", str(executable)], check=True, capture_output=True)
            subprocess.run([str(executable)], check=True, capture_output=True)

    @unittest.skipUnless(shutil.which("xcrun") and shutil.which("swift"), "header validation requires Xcode")
    def test_private_ffmpeg_headers_win_over_app_frameworks(self):
        package = dump_package("PPSSPP")
        targets = {target["name"]: target for target in package["targets"]}
        private = ROOT / "Cores/PPSSPP/cmake/ffmpeg/ios/universal/include"
        with tempfile.TemporaryDirectory(prefix="ppsspp-ffmpeg-") as temporary:
            shared = Path(temporary) / "libavcodec.framework/Headers"
            shared.mkdir(parents=True)
            (shared / "avcodec.h").write_text("#error Wrong_shared_FFmpeg_header\n")
            source = '\n'.join([
                'extern "C" {', '#include "libavcodec/avcodec.h"', '}',
                'static_assert(sizeof(AVCodecContext)>0, "legacy context required");',
                'void check() { AVCodec *codec=avcodec_find_decoder(AV_CODEC_ID_H264); (void)codec; }',
            ])
            base = ["xcrun", "clang++", "-x", "c++", "-fsyntax-only", "-F", temporary, "-I", str(private)]
            wrong = subprocess.run(base + ["-"], input=source, text=True, capture_output=True)
            self.assertNotEqual(wrong.returncode, 0, "fixture must reproduce the shared framework collision")
            for name in ["PVPPSSPPCore", "PVPPSSPPnative", "PVPPSSPPBridge"]:
                with self.subTest(target=name):
                    flags = [flag for setting in targets[name]["settings"] if setting["tool"] == "cxx"
                             for flag in setting["kind"].get("unsafeFlags", {}).get("_0", [])]
                    priorities = [argument for index, flag in enumerate(flags) if flag == "-iquote"
                                  for argument in flags[index:index + 2]]
                    result = subprocess.run(base + priorities + ["-"], input=source, text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("swift"), "swift toolchain not installed")
    def test_native_engine_is_source_built(self):
        package = dump_package("PPSSPP")
        self.assertFalse(any(target["type"] == "binary" for target in package["targets"]))
        targets = {target["name"]: target for target in package["targets"]}
        sources = [source for target in package["targets"] for source in target.get("sources", [])]
        self.assertEqual(len(sources), len(set(sources)), "duplicate native archive members")
        for source in sources:
            self.assertTrue((ROOT / "Cores/PPSSPP" / source).is_file(), f"declared source is missing: {source}")
        self.assertIn("libretro_ppsspp/Core/System.cpp", sources)
        self.assertIn("PVPPSSPPCore/Core/MemArenaDarwin.cpp", sources)
        self.assertIn("PVPPSSPPCore/Core/iOSCoreAudio.mm", sources)
        self.assertNotIn("libretro_ppsspp/ios/iOSCoreAudio.mm", sources)
        self.assertEqual(len(targets["PVPPSSPP"]["sources"]), 8)
        self.assertEqual(len(targets["PVPPSSPPBridge"]["sources"]), 12)
        self.assertEqual(targets["PVPPSSPPBridge"]["resources"][0]["path"], "cmake/assets")


if __name__ == "__main__":
    unittest.main()
