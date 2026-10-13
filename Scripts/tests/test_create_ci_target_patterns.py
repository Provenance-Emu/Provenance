"""create_ci_target.rb must strip every core from Provenance-CI, including SwiftPM products.

Its CORE_PATTERNS are matched against framework and package product names; a core missing
from the list would be kept in the coreless CI target when the script is re-run.
"""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/dev/create_ci_target.rb"

# Products/frameworks that are core code and must never reach Provenance-CI.
CORE_NAMES = [
    "PVStella-Dynamic", "PVCoremGBA-Dynamic", "PVSNES9x-Dynamic", "PVFCEU-Dynamic",
    "PVCoreGenesisPlus-Dynamic", "PVMupenGameCore-Dynamic", "PVMupen64PlusRspHLE-Dynamic",
    "PVRSPCXD4-Dynamic", "PVMupen64PlusVideoRice-Dynamic", "PVMupen64PlusVideoGlideN64-Dynamic",
    "PVAzahar.framework", "PVDolphin.framework", "PVCoreMednafen-Dynamic", "PVGambatte",
]


def matching(names):
    ruby = (
        'src = File.read(ARGV.shift); '
        'eval(src[/^CORE_PATTERNS = \\[.*?^\\]/m]); '
        'puts ARGV.map { |n| [n, CORE_PATTERNS.any? { |p| n =~ p }] }.to_h.to_a.map { |n, m| "#{n}\\t#{m}" }'
    )
    out = subprocess.run(["ruby", "-e", ruby, str(SCRIPT), *names], check=True,
                         capture_output=True, text=True).stdout
    return {line.split("\t")[0]: line.split("\t")[1] == "true" for line in out.splitlines()}


class CorePatternTests(unittest.TestCase):
    def test_every_core_is_stripped(self):
        result = matching(CORE_NAMES)
        self.assertEqual([n for n, matched in result.items() if not matched], [])


if __name__ == "__main__":
    unittest.main()
