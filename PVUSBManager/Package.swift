// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVUSBManager",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVUSBManager",
            targets: ["PVUSBManager"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PVUSBManager",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PVUSBManagerTests",
            dependencies: ["PVUSBManager"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
