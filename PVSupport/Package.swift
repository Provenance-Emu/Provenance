// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSupport",
    platforms: [
        .iOS(.v15),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVSupport",
            targets: ["PVSupport"]),
        .library(
            name: "PVSupport-Dynamic",
            type: .dynamic,
            targets: ["PVSupport"]),
        .library(
            name: "PVSupport-Static",
            type: .static,
            targets: ["PVSupport"]),
    ],

    dependencies: [
        .package(path: "../PVLogging/"),
        .package(path: "../PVSettings/"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git",branch: "develop")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVSupport
        .target(
            name: "PVSupport",
            dependencies: [
                "PVLogging",
                "PVSettings"
            ],
            resources: [
                .process("Resources/AHAP/"),
                .copy("PrivacyInfo.xcprivacy")
            ],
            cSettings: [
                .define("GLES_SILENCE_DEPRECATION", to: "1"),
                .define("NONJAILBROKEN", to: "1", .when(configuration: .release)),
            ],
            swiftSettings: [
                .define("GLES_SILENCE_DEPRECATION"),
                .define("NONJAILBROKEN", .when(configuration: .release)),
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ],
            plugins: [
//                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
//                .plugin(name: "SwiftGen-Generate", package: "SwiftGenPlugin")
            ]
        ),

        .testTarget(
            name: "PVSupportTests",
            dependencies: ["PVSupport"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
