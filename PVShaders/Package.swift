// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVShaders",
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
            name: "PVShaders",
            targets: ["PVShaders"]
        )
    ],
    dependencies: [
        .package(path: "../PVPrimitives"),
        .package(path: "../PVLogging"),
        .package(path: "../PVSettings")
    ],
    targets: [
        .target(
            name: "PVShaders",
            dependencies: [
                "PVPrimitives",
                "PVLogging",
                "PVSettings"
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
