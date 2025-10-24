// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVCoreAudio",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v12),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVCoreAudio",
            targets: ["PVCoreAudio"]),
         .library(
             name: "PVCoreAudio-Dynamic",
             type: .dynamic,
             targets: ["PVCoreAudio"]),
         .library(
             name: "PVCoreAudio-Static",
             type: .static,
             targets: ["PVCoreAudio"]),
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVCoreBridge", path: "../PVCoreBridge/"),
        .package(name: "PVSettings", path: "../PVSettings/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVAudio", path: "../PVAudio/"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", branch: "main"),
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVCoreAudio
        .target(
            name: "PVCoreAudio",
            dependencies: [
                "PVCoreBridge",
                "PVSettings",
                "Defaults",
                .product(name: "PVAudio", package: "PVAudio"),
                .product(name: "PVLogging", package: "PVLogging"),
//                "NotifyWrapper"
            ],
            path: "Sources/PVCoreAudio",
            cSettings: [
                .headerSearchPath("Utilities"),
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVCoreAudioTests",
            dependencies: ["PVCoreAudio"]
        )
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
