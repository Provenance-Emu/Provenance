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
        .package(url: "https://github.com/Provenance-Emu/PVSystems.git", from: "1.0.3"),
        .package(path: "../PVLogging"),
        .package(url: "https://github.com/Provenance-Emu/emulator-content-server.git", revision: "7b30839778e502573ee0cfb91c4bf94a1de51fa8"),
        .package(url: "https://github.com/Provenance-Emu/PVRemoteLibrary.git", from: "0.3.2")
    ],
    targets: [
        .target(
            name: "PVLibrarySharing",
            dependencies: [
                .product(name: "PVSystems", package: "PVSystems"),
                "PVLogging",
                .product(name: "EmulatorContentClient", package: "emulator-content-server"),
                .product(name: "RomMClient", package: "emulator-content-server"),
                .product(name: "PVRemoteLibrary", package: "PVRemoteLibrary")
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLibrarySharingTests",
            dependencies: [
                "PVLibrarySharing",
                .product(name: "RomMClient", package: "emulator-content-server"),
                .product(name: "PVSystems", package: "PVSystems"),
                .product(name: "PVRemoteLibrary", package: "PVRemoteLibrary")
            ],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5, .v6]
)
