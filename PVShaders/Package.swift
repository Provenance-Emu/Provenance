// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVShaders",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v12),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVShaders",
            targets: ["PVShaders"]
        )
    ],
    dependencies: [
        .package(path: "../PVPrimitives"),
        .package(path: "../PVLogging"),
        .package(path: "../PVSettings"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2")
    ],
    targets: [
        .target(
            name: "PVShaders",
            dependencies: [
                "PVPrimitives",
                "PVLogging",
                "PVSettings",
                "Defaults"
            ],
            resources: [
                .process("Resources/Metal")
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
