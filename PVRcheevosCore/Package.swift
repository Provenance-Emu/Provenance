// swift-tools-version: 5.9
// PVRcheevosCore — Pure-Swift rcheevos utilities with no C library dependency.
//
// This package contains byte-swap helpers, address-space constants, and the
// pure-Swift RcheevosMemoryRegion descriptor.
//
// It has NO dependency on CRcheevos (no git submodule required), so it compiles
// and tests on all platforms — including Linux — without the rcheevos submodule.
//
// ## Usage
//
// Tier 0 module — run tests with:
//   cd PVRcheevosCore && swift test
//
// The full rcheevos C library lives in PVRcheevos/ (depends on the rcheevos submodule).
// PVRcheevos re-exports PVRcheevosCore so consumers get both with one import.
//

import PackageDescription

let package = Package(
    name: "PVRcheevosCore",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v14),
        .macCatalyst(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "PVRcheevosCore", targets: ["PVRcheevosCore"]),
    ],
    targets: [
        // MARK: - PVRcheevosCore
        .target(
            name: "PVRcheevosCore",
            path: "Sources/PVRcheevosCore"
        ),
        // MARK: - Tests
        //
        // No rcheevos submodule required — runs standalone.
        // Run: cd PVRcheevosCore && swift test
        .testTarget(
            name: "PVRcheevosTests",
            dependencies: ["PVRcheevosCore"],
            path: "Tests/PVRcheevosTests"
        ),
    ]
)
