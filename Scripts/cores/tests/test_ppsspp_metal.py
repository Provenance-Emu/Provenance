"""Compile PPSSPP's actual drawable proxy against device and simulator Metal APIs."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "Cores/PPSSPP/PVPPSSPPCore/Core/PPSSPPVulkanViewController.swift"


def presentation_source(source):
    declarations = source[source.index("fileprivate enum PPSSPPFilterPresentationTiming"):
                          source.index("fileprivate final class PPSSPPFilterHostingView")]
    methods = []
    for name in ["schedulePresent", "presentBaseDrawable"]:
        start = source.index(f"    private func {name}(")
        brace = source.index("{", start)
        depth = 1
        end = brace + 1
        while depth:
            depth += (source[end] == "{") - (source[end] == "}")
            end += 1
        methods.append(source[start:end])
    return "import UIKit\nimport Metal\nimport QuartzCore\n" + declarations + "\nprivate class Harness {\n" + "\n".join(methods) + "\n}\n"


@unittest.skipUnless(shutil.which("xcrun"), "requires Xcode")
class PPSSPPMetalTests(unittest.TestCase):
    def test_drawable_proxy_matches_each_apple_sdk(self):
        with tempfile.TemporaryDirectory(prefix="ppsspp-metal-") as temporary:
            source = Path(temporary) / "Presentation.swift"
            source.write_text(presentation_source(SOURCE.read_text()))
            for sdk, platform, simulator in [("iphoneos", "ios", False), ("iphonesimulator", "ios", True),
                                              ("appletvos", "tvos", False), ("appletvsimulator", "tvos", True)]:
                with self.subTest(sdk=sdk):
                    sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
                    triple = f"arm64-apple-{platform}17.0" + ("-simulator" if simulator else "")
                    result = subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-typecheck",
                                             "-sdk", sdk_path, "-target", triple, str(source)], text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
