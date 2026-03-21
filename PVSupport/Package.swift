// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

#if os(Linux)
let platformDeps: [Package.Dependency] = []
let platformTargetDeps: [Target.Dependency] = []
#else
let platformDeps: [Package.Dependency] = [
    .package(path: "../PVSettings/"),
    .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.0.0")
]
let platformTargetDeps: [Target.Dependency] = [
    "PVSettings"
]
#endif

let package = Package(
    name: "PVSupport",
    platforms: [
        .iOS(.v17),
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
    ] + platformDeps,

    // MARK: - Targets
    targets: [
        // MARK: - PVSupport
        .target(
            name: "PVSupport",
            dependencies: [
                "PVLogging",
            ] + platformTargetDeps,
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
