// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSpeach",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVSpeach",
            targets: ["PVSpeach"]),
        .library(
            name: "PVSpeach-Static",
            type: .static,
            targets: ["PVSpeach"]),
        .library(
            name: "PVSpeach-Dynamic",
            type: .dynamic,
            targets: ["PVSpeach"]),
        .library(
            name: "PVSpeachUI",
            targets: ["PVSpeachUI"]),
        .library(
            name: "PVSpeachUI-Static",
            type: .static,
            targets: ["PVSpeachUI"]),
        .library(
            name: "PVSpeachUI-Dynamic",
            type: .dynamic,
            targets: ["PVSpeachUI"]),
    ],

    dependencies: [
        .package(
            url: "https://github.com/JoeMatt/OSSSpeechKit.git",
            .upToNextMajor(from: "0.4.0")
        )
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVSpeach
        .target(
            name: "PVSpeach",
            dependencies: [
                .product(name: "OSSSpeechKit", package: "OSSSpeechKit"),
            ],
            linkerSettings: []
        ),
        // MARK: - PVSpeachUI
        .target(
            name: "PVSpeachUI",
            dependencies: [
                "PVSpeach",
            ],
            linkerSettings: []
        )
    ]
)
