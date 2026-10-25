#!/usr/bin/env python3
"""Compile the production queue-claim synchronization and its XCTest cases on macOS."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="provenance-import-claim-") as name:
    package = Path(name)
    (package / "Sources").mkdir()
    (package / "Tests").mkdir()
    source = root / "PVLibrary/Sources/PVLibrary/Importer/Models/ImportQueueClaim.swift"
    tests = root / "PVLibrary/Tests/PVLibraryTests/ImportQueueClaimTests.swift"
    (package / "Sources/ImportQueueClaim.swift").write_text(source.read_text())
    (package / "Tests/ImportQueueClaimTests.swift").write_text(tests.read_text())
    (package / "Package.swift").write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "ImportClaimHarness", platforms: [.macOS(.v14)], targets: [
    .target(name: "PVLibrary", path: "Sources"),
    .testTarget(name: "ClaimTests", dependencies: ["PVLibrary"], path: "Tests")
])
''')
    raise SystemExit(subprocess.call(["swift", "test", "--package-path", str(package), "--jobs", "4"]))
