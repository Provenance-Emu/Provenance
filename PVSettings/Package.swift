// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSettings",
    platforms: [
        .iOS(.v15),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVSettings",
            targets: ["PVSettings"]),
    ],

    dependencies: [
        .package(path: "../PVLogging"),
//        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.0-beta.3"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", branch: "main"),
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVSupport
        .target(
            name: "PVSettings",
            dependencies: [
                "PVLogging",
                "Defaults"
            ]
        ),

        .testTarget(
            name: "PVSettingsTests",
            dependencies: ["PVSettings"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
