"""Validate the platform/ABI contract of PPSSPP's legacy FFmpeg distribution."""
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CORE = ROOT / "Cores/PPSSPP"
BUNDLE = CORE / "SwiftPM/FFmpeg/PPSSPPFFmpeg.xcframework"


class PPSSPPFFmpegTests(unittest.TestCase):
    def test_device_and_simulator_slices_are_distinct(self):
        info = plistlib.loads((BUNDLE / "Info.plist").read_bytes())
        slices = {(s["SupportedPlatform"], s.get("SupportedPlatformVariant")): s for s in info["AvailableLibraries"]}
        self.assertEqual(set(slices), {("ios", None), ("tvos", None), ("ios", "simulator"), ("tvos", "simulator")})
        for entry in slices.values():
            self.assertEqual(entry["SupportedArchitectures"], ["arm64"])
            self.assertTrue((BUNDLE / entry["LibraryIdentifier"] / entry["LibraryPath"]).is_file())

    @unittest.skipUnless(shutil.which("xcrun"), "requires Xcode")
    def test_legacy_codec_api_links_on_both_simulators(self):
        info = plistlib.loads((BUNDLE / "Info.plist").read_bytes())
        with tempfile.TemporaryDirectory(prefix="ppsspp-codec-") as temporary:
            directory = Path(temporary)
            source = directory / "codec.c"
            source.write_text('''
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswresample/swresample.h"
#include "libswscale/swscale.h"
int main(void) {
    av_register_all();
    AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_ATRAC3P);
    AVCodecContext *context = avcodec_alloc_context3(codec);
    int result = avcodec_open2(context, codec, 0);
    avcodec_free_context(&context);
    return result + (swresample_version() == 0) + (swscale_version() == 0);
}
''')
            for sdk, platform, expected in [("iphonesimulator", "ios", "7"),
                                            ("appletvsimulator", "tvos", "8")]:
                entry = next(s for s in info["AvailableLibraries"] if s["SupportedPlatform"] == platform
                             and s.get("SupportedPlatformVariant") == "simulator")
                library = BUNDLE / entry["LibraryIdentifier"] / entry["LibraryPath"]
                headers = CORE / "cmake/ffmpeg/ios/universal/include"
                sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
                subprocess.run(["xcrun", "--sdk", sdk, "clang", "-target", f"arm64-apple-{platform}17.0-simulator",
                                "-isysroot", sdk_path, "-I", str(headers), str(source), str(library),
                                "-lz", "-o", str(directory / sdk)], check=True, capture_output=True)
                objects = subprocess.check_output(["xcrun", "otool", "-l", str(library)], text=True)
                platforms = [line.split()[-1] for line in objects.splitlines() if line.strip().startswith("platform ")]
                self.assertTrue(platforms)
                self.assertEqual(set(platforms), {expected})


if __name__ == "__main__":
    unittest.main()
