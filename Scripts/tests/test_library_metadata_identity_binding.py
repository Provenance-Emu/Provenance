#!/usr/bin/env python3
"""Compile whole production binding source/tests against published PVLibraryMetadata."""
from pathlib import Path
import subprocess
import tempfile
import sys

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="provenance-identity-binding-") as directory:
    package = Path(directory)
    (package / "Sources").mkdir()
    (package / "Tests").mkdir()
    (package / "Sources/LibraryMetadataIdentityBinding.swift").symlink_to(
        root / "PVLibrary/Sources/PVLibrary/Services/LibraryMetadata/LibraryMetadataIdentityBinding.swift")
    (package / "Tests/LibraryMetadataIdentityBindingTests.swift").symlink_to(
        root / "PVLibrary/Tests/PVLibraryTests/LibraryMetadata/LibraryMetadataIdentityBindingTests.swift")
    (package / "Package.swift").write_text('''// swift-tools-version:6.0
import PackageDescription
let package = Package(name: "BindingHarness", platforms: [.macOS(.v14)], dependencies: [
    .package(url: "https://github.com/Provenance-Emu/PVCloudSync.git", exact: "1.1.0")
], targets: [
    .target(name: "PVLibrary", dependencies: [.product(name: "PVLibraryMetadata", package: "PVCloudSync")], path: "Sources"),
    .testTarget(name: "BindingTests", dependencies: ["PVLibrary", .product(name: "PVLibraryMetadata", package: "PVCloudSync")], path: "Tests")
], swiftLanguageModes: [.v5])
''')
    result = subprocess.call(["/usr/bin/xcrun", "swift", "test", "--build-system", "native", "--package-path", str(package), "--jobs", "4", *sys.argv[1:]])
    resolved = package / "Package.resolved"
    if resolved.exists():
        import json
        pins = json.loads(resolved.read_text())["pins"]
        pin = next(p for p in pins if p["identity"] == "pvcloudsync")
        assert pin["state"]["revision"] == "890c83f81dafc5aeb11245de3b0e47df5f1670e5", pin
    raise SystemExit(result)
