"""Legacy emuThree dependencies must carry real arm64 platform slices."""
import plistlib
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BUNDLE = ROOT / "Cores/emuThree/SwiftPM/Vendors/PVEmuThreeVendors.xcframework"


class EmuThreeVendorTests(unittest.TestCase):
    def test_all_apple_destinations_have_distinct_arm64_slices(self):
        slices = plistlib.loads((BUNDLE / "Info.plist").read_bytes())["AvailableLibraries"]
        self.assertEqual({(s["SupportedPlatform"], s.get("SupportedPlatformVariant")) for s in slices},
                         {("ios", None), ("tvos", None), ("ios", "simulator"), ("tvos", "simulator")})
        for entry in slices:
            self.assertEqual(entry["SupportedArchitectures"], ["arm64"])
            self.assertNotIn("HeadersPath", entry, "OpenAL headers must not collide with the app OpenAL binary")

    @unittest.skipUnless(shutil.which("xcrun"), "requires Xcode")
    def test_openal_callback_api_links_for_all_apple_sdks(self):
        slices = plistlib.loads((BUNDLE / "Info.plist").read_bytes())["AvailableLibraries"]
        package = json.loads(subprocess.check_output(
            ["xcrun", "swift", "package", "--package-path", str(ROOT / "Cores/emuThree"), "dump-package"], text=True))
        engine = next(t for t in package["targets"] if t["name"] == "PVEmuThreeEngine")
        settings = [s for s in engine["settings"] if s["tool"] == "linker"]
        with tempfile.TemporaryDirectory(prefix="emuthree-openal-") as temporary:
            source = Path(temporary) / "audio.cpp"
            source.write_text("""
#define AL_ALEXT_PROTOTYPES 1
#include <AL/al.h>
#include <AL/alc.h>
#include <AL/alext.h>
static ALsizei callback(void *, void *, ALsizei) { return 0; }
int main() {
    ALuint buffer = 0;
    alGenBuffers(1, &buffer);
    alBufferCallbackSOFT(buffer, AL_FORMAT_STEREO16, 44100, callback, nullptr);
    return alGetError() + (alcOpenDevice(nullptr) == nullptr);
}
""")
            for sdk, platform, simulator in [("iphoneos", "ios", False), ("iphonesimulator", "ios", True),
                                              ("appletvos", "tvos", False), ("appletvsimulator", "tvos", True)]:
                with self.subTest(sdk=sdk):
                    entry = next(s for s in slices if s["SupportedPlatform"] == platform
                                 and (s.get("SupportedPlatformVariant") == "simulator") == simulator)
                    directory = BUNDLE / entry["LibraryIdentifier"]
                    sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
                    triple = f"arm64-apple-{platform}17.0" + ("-simulator" if simulator else "")
                    flags = []
                    for setting in settings:
                        if platform not in setting.get("condition", {}).get("platformNames", [platform]):
                            continue
                        if "linkedFramework" in setting["kind"]:
                            flags += ["-framework", setting["kind"]["linkedFramework"]["_0"]]
                        elif "linkedLibrary" in setting["kind"]:
                            flags += ["-l" + setting["kind"]["linkedLibrary"]["_0"]]
                    result = subprocess.run(["xcrun", "clang++", "-target", triple, "-isysroot", sdk_path,
                                             "-I", str(BUNDLE.parent / "Headers"), str(source),
                                             str(directory / entry["LibraryPath"]), *flags,
                                             "-o", str(Path(temporary) / sdk)], text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("xcrun"), "requires Xcode")
    def test_simulator_objects_and_vendor_symbols(self):
        slices = plistlib.loads((BUNDLE / "Info.plist").read_bytes())["AvailableLibraries"]
        for entry in slices:
            if entry.get("SupportedPlatformVariant") != "simulator":
                continue
            with self.subTest(platform=entry["SupportedPlatform"]):
                library = BUNDLE / entry["LibraryIdentifier"] / entry["LibraryPath"]
                objects = subprocess.check_output(["xcrun", "otool", "-l", str(library)], text=True)
                platforms = {line.split()[-1] for line in objects.splitlines() if line.strip().startswith("platform ")}
                self.assertEqual(platforms, {"7" if entry["SupportedPlatform"] == "ios" else "8"})
                self.assertNotIn("LC_VERSION_MIN_IPHONEOS", objects)
                symbols = subprocess.check_output(["xcrun", "nm", "-gU", str(library)], text=True, stderr=subprocess.DEVNULL)
                for name in ["__ZN8Dynarmic3A323JitC1ENS0_10UserConfigE", "__ZN10soundtouch10SoundTouchC1Ev", "__ZN10soundtouch10SoundTouch10putSamplesEPKsj",
                             "_enet_initialize", "_ZSTD_decompress", "_alBufferCallbackSOFT", "_alcOpenDevice"]:
                    self.assertIn(name, symbols)


if __name__ == "__main__":
    unittest.main()
