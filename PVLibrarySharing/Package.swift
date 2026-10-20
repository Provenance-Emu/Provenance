// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

/// Cross-app library sharing: discovers iFly and iCube (later Provenance and
/// emulator-content-server) libraries on the LAN and browses them.
/// Design: docs/superpowers/specs/2026-10-14-cross-app-library-sharing-design.md
///
/// No Realm and no UIKit, so `swift test` runs on the macOS host.
let package = Package(
    name: "PVLibrarySharing",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVLibrarySharing",
            targets: ["PVLibrarySharing"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Provenance-Emu/PVSystems.git", from: "1.0.0"),
        .package(path: "../PVLogging")
    ],
    targets: [
        .target(
            name: "PVLibrarySharing",
            dependencies: [
                .product(name: "PVSystems", package: "PVSystems"),
                "PVLogging"
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLibrarySharingTests",
            dependencies: ["PVLibrarySharing", .product(name: "PVSystems", package: "PVSystems")],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5, .v6]
)
