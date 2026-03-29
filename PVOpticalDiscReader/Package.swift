// swift-tools-version:5.9
// PVOpticalDiscReader — thin IPC client to the optical drive DriverKit extension.
//
// Tier 3 module (depends on PVLogging).
// Compiles for: iOS 17+, macOS 14+, tvOS 17+, visionOS 1+
// On tvOS there is no USB optical drive support, so only the data types are exposed.

import PackageDescription

let package = Package(
    name: "PVOpticalDiscReader",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "PVOpticalDiscReader", targets: ["PVOpticalDiscReader"])
    ],
    dependencies: [
        .package(path: "../PVLogging")
    ],
    targets: [
        .target(
            name: "PVOpticalDiscReader",
            dependencies: [
                .product(name: "PVLogging", package: "PVLogging")
            ],
            path: "Sources/PVOpticalDiscReader",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PVOpticalDiscReaderTests",
            dependencies: ["PVOpticalDiscReader"],
            path: "Tests/PVOpticalDiscReaderTests"
        )
    ]
)
