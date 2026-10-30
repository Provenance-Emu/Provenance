#!/usr/bin/env python3
"""Drive the real installed app's library hub, retaining XCTest screenshots and logs.

Build/install the app first. Requires XcodeGen and a booted iOS/tvOS simulator.
"""
import argparse
import json
from pathlib import Path
import subprocess
from datetime import datetime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["ios", "tvos"], required=True)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--app-bundle", default="org.provenance-emu.provenance.dev.coreless")
    parser.add_argument("--test", choices=["testRealLibraryHub", "testGameContextMenuOpensDetailsOnce"])
    parser.add_argument("--game-title", default="Theme Preview", help="Imported synthetic game used for the library/context-menu checks")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = root / "build/netplay-hub-smoke" / (args.platform + "-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    output.mkdir(parents=True)
    target = "NetplayHubSmokeTests"
    spec = {
        "name": "NetplayHubSmoke",
        "settings": {"base": {"CODE_SIGN_IDENTITY": "-", "CODE_SIGN_STYLE": "Manual", "DEVELOPMENT_TEAM": "", "GENERATE_INFOPLIST_FILE": "YES"}},
        "targets": {target: {
            "type": "bundle.ui-testing", "platform": "iOS" if args.platform == "ios" else "tvOS", "deploymentTarget": "17.0",
            "sources": [str(root / "Scripts/tests/fixtures/netplay-hub")],
            "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "org.provenance-emu.netplay-hub-smoke"}},
        }},
        "schemes": {target: {
            "build": {"targets": {target: "all"}},
            "test": {"targets": [target], "environmentVariables": {"NETPLAY_APP_BUNDLE": args.app_bundle, "NETPLAY_GAME_TITLE": args.game_title}},
        }},
    }
    path = output / "project.json"
    path.write_text(json.dumps(spec, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(path), "--project", str(output)], check=True)
    destination = f"platform={'iOS' if args.platform == 'ios' else 'tvOS'} Simulator,id={args.udid}"
    with (output / "test.log").open("w") as log:
        result = subprocess.run([
            "xcrun", "xcodebuild", "-project", str(output / "NetplayHubSmoke.xcodeproj"), "-scheme", target,
            "-destination", destination, "-derivedDataPath", str(root / "build/netplay-hub-smoke/DerivedData" / args.platform),
            "-collect-test-diagnostics", "never", "-resultBundlePath", str(output / "Results.xcresult"), "ARCHS=arm64", *([f"-only-testing:{target}/NetplayHubIntegratedTests/{args.test}"] if args.test else []), "test",
        ], stdout=log, stderr=subprocess.STDOUT)
    print(f"Evidence: {output}")
    if (output / "Results.xcresult").exists():
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(output / "Results.xcresult"),
                        "--output-path", str(output / "attachments")], check=False)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
