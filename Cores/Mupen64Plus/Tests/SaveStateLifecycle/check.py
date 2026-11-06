#!/usr/bin/env python3
"""macOS regression test: production save operation and callback registry, fake engine.

Requires the pinned Mupen core submodule and Apple's clang/Foundation. This does
not establish native engine persistence; run the simulator/device roundtrip too.
"""
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
CORE = HERE.parents[1]
BRIDGE = CORE / "Sources/PVMupenBridge"
SCENARIOS = (
    "cached-ready", "future-ready", "failure", "terminal-stop", "no-ready-event",
    "nil", "accepted-stop", "accepted-slow", "unpaused", "busy-pending", "busy-accepted",
)


def method(source, signature):
    start = source.index(signature, source.index("@implementation PVMupenBridge"))
    return source[start:source.index("\n}", start) + 2]


def main():
    registry = (BRIDGE / "PVMupenBridge.m").read_text()
    saves = (BRIDGE / "PVMupenBridge+Saves.m").read_text()
    methods = "\n".join(method(registry, signature) for signature in (
        "- (void)OE_addHandlerForType:",
        "- (BOOL)OE_claimSaveStateRequest:",
        "- (void)OE_releaseSaveStateRequest:",
        "- (void)OE_performCallbackOperation:",
        "- (void)OE_removeHandlerForType:",
        "- (oneway void)OE_didReceiveStateChangeForParamType:",
    ))
    request = saves[saves.index("// Readiness uses"):saves.index("- (BOOL)loadStateFromFileAtPath:")] + "\n@end\n"
    template = (HERE / "Harness.m.in").read_text()
    source = template.replace("// @@REGISTRY@@", methods).replace("// @@SAVE_REQUEST@@", request)
    source = source.replace("@@TYPES_HEADER@@", str(CORE / "Sources/Plugins/Core/Core/src/api/m64p_types.h"))
    results = {}
    with tempfile.TemporaryDirectory(prefix="mupen-save-lifecycle-") as temp:
        path = Path(temp)
        (path / "Harness.m").write_text(source)
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-Wno-return-type",
            "-framework", "Foundation", str(path / "Harness.m"), "-o", str(path / "harness"),
        ], check=True)
        for scenario in SCENARIOS:
            result = subprocess.run([str(path / "harness"), scenario], capture_output=True, text=True, timeout=9)
            results[scenario] = {"exit": result.returncode, "output": result.stdout, "stderr": result.stderr}
    print(json.dumps(results, indent=2))
    return int(any(result["exit"] != 0 for result in results.values()))


if __name__ == "__main__":
    raise SystemExit(main())
