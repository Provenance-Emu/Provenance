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
import sys
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


class NativeFrameworkTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("xcrun") and shutil.which("swift"), "framework validation requires Xcode")
    def test_frameworks_link_on_both_device_and_simulator_sdks(self):
        with tempfile.TemporaryDirectory(prefix="core-frameworks-") as temporary:
            source = Path(temporary) / "main.c"
            source.write_text("int main(void) { return 0; }\n")
            for core in ["PPSSPP", "emuThree", "Dolphin", "Azahar"]:
                settings = [setting for target in dump_package(core)["targets"] for setting in target.get("settings", [])
                            if setting["tool"] == "linker" and "linkedFramework" in setting["kind"]]
                for sdk, platform, simulator in [("iphoneos", "ios", False), ("iphonesimulator", "ios", True),
                                                  ("appletvos", "tvos", False), ("appletvsimulator", "tvos", True)]:
                    with self.subTest(core=core, sdk=sdk):
                        flags = []
                        for setting in settings:
                            if platform in setting.get("condition", {}).get("platformNames", [platform]):
                                flags += ["-framework", setting["kind"]["linkedFramework"]["_0"]]
                        sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
                        triple = f"arm64-apple-{platform}17.0" + ("-simulator" if simulator else "")
                        result = subprocess.run(["xcrun", "clang", "-target", triple, "-isysroot", sdk_path,
                                                 str(source), *flags, "-o", str(Path(temporary) / sdk)], text=True, capture_output=True)
                        self.assertEqual(result.returncode, 0, result.stderr)


class RetroLinkageTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform == "darwin" and shutil.which("xcrun"), "requires Apple SDKs")
    def test_c_callbacks_and_vulkan_headers(self):
        root = ROOT

        def run(*args):
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return result.stdout

        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            # Stub only the JITManager dependency; compile the actual callback implementations with release optimization.
            jit = (root / "PVCoreBridgeRetro/Sources/PVLibRetro/PVLibRetro+JIT.swift").read_text()
            jit = jit.replace(
                "#if !os(tvOS)\nimport JITManager\n#endif", "enum DOLJitManager { static let acquired = false }"
            )
            (t / "JIT.swift").write_text(jit)
            policy = root / "PVCoreBridgeRetro/Sources/PVLibRetro/ThinVFSDiskImagePolicy.swift"
            run(
                "xcrun",
                "swiftc",
                "-parse-as-library",
                "-O",
                "-whole-module-optimization",
                "-emit-library",
                "-emit-objc-header-path", str(t / "support.h"),
                str(t / "JIT.swift"),
                str(policy),
                "-o",
                str(t / "support.dylib"),
            )
            frontend = (root / "PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.mm").read_text()
            declarations = re.findall(r'^extern "C" bool pv(?:jit_acquired|_thin_vfs_should_memory_map).*?;', frontend, re.M)
            self.assertEqual(len(declarations), 2)
            (t / "declarations.mm").write_text('#include "support.h"\n' + "\n".join(declarations))
            run("xcrun", "clang++", "-fsyntax-only", "-fmodules", "-fcxx-modules", str(t / "declarations.mm"))
            symbols = run("nm", "-gU", str(t / "support.dylib"))
            for name in ("_pvjit_acquired", "_pv_thin_vfs_should_memory_map"):
                self.assertIn(name, symbols, f"Callback not exported: {name}")
            (t / "client.c").write_text(
                """#include <stdbool.h>
        #include <stdint.h>
        extern bool pvjit_acquired(void);
        extern bool pv_thin_vfs_should_memory_map(const char *, uint32_t, uint32_t, int64_t);
        int main(void) {
         if (pvjit_acquired()) return 1;
         if (!pv_thin_vfs_should_memory_map("disc.iso", 1, 0, 1024)) return 2;
         if (pv_thin_vfs_should_memory_map(0, 1, 0, 1024)) return 3;
         return 0;
        }
        """
            )
            run("xcrun", "clang", str(t / "client.c"), str(t / "support.dylib"), "-o", str(t / "client"))
            run(str(t / "client"))
            print("PASS: optimized Swift callbacks exported, linked from C, and executed")
            (t / "headers.mm").write_text(
                '#include "PVCoreBridgeRetro/Sources/ExternalHeaders/MoltenVK/vulkan/vulkan.h"\n'
                '#include "PVCoreBridgeRetro/Sources/ExternalHeaders/MoltenVK/vulkan/vk_platform.h"\n'
                '#include "PVCoreBridgeRetro/Sources/ExternalHeaders/MoltenVK/vk_video/vulkan_video_codecs_common.h"\n'
            )
            for sdk in ("macosx", "iphoneos", "iphonesimulator", "appletvos", "appletvsimulator"):
                sdkroot = run("xcrun", "--sdk", sdk, "--show-sdk-path").strip()
                target = {
                    "macosx": "arm64-apple-macos14",
                    "iphoneos": "arm64-apple-ios17",
                    "iphonesimulator": "arm64-apple-ios17-simulator",
                    "appletvos": "arm64-apple-tvos17",
                    "appletvsimulator": "arm64-apple-tvos17-simulator",
                }[sdk]
                run(
                    "xcrun",
                    "clang++",
                    "-fsyntax-only",
                    "-fmodules",
                    "-fcxx-modules",
                    "-Werror=module-import-in-extern-c",
                    "-isysroot",
                    sdkroot,
                    "-target",
                    target,
                    "-I",
                    str(root),
                    "-I", str(root / "MoltenVK/MoltenVK/include"),
                    str(t / "headers.mm"),
                )
                print(f"PASS: Vulkan headers with C++ modules ({sdk})")


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

    @unittest.skipUnless(shutil.which("xcrun"), "native module validation requires Xcode")
    def test_zstd_private_api_survives_app_module_maps(self):
        core = ROOT / "Cores/PPSSPP"
        source = core / "libretro_ppsspp/ext/zstd/lib/compress/zstdmt_compress.c"
        target = next(t for t in dump_package("PPSSPP")["targets"] if t["name"] == "PVPPSSPPlibzstdstatic")
        flags = [flag for setting in target["settings"] if setting["tool"] == "c"
                 for flag in setting["kind"].get("unsafeFlags", {}).get("_0", [])]
        with tempfile.TemporaryDirectory(prefix="ppsspp-zstd-modules-") as temporary:
            modulemap = Path(temporary) / "module.modulemap"
            header = core / "libretro_ppsspp/ext/zstd/lib/zstd.h"
            modulemap.write_text(f'module libzstd {{ header "{header}" export * }}\n')
            for sdk, triple in [("iphoneos", "arm64-apple-ios17"), ("iphonesimulator", "arm64-apple-ios17-simulator"),
                                ("appletvos", "arm64-apple-tvos17"), ("appletvsimulator", "arm64-apple-tvos17-simulator")]:
                with self.subTest(sdk=sdk):
                    sdkroot = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
                    result = subprocess.run(["xcrun", "clang", "-fsyntax-only", "-target", triple, "-isysroot", sdkroot,
                                             "-fmodules", f"-fmodule-map-file={modulemap}", *flags, str(source)],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)

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
        self.assertEqual([target["name"] for target in package["targets"] if target["type"] == "binary"], ["PPSSPPFFmpeg"])
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
