// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PVNetplay",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1),
        .macCatalyst(.v17)
    ],
    products: [
        .library(name: "PVNetplay", targets: ["PVNetplay"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PVNetplay",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "PVNetplayTests",
            dependencies: ["PVNetplay"]
        )
    ]
)
