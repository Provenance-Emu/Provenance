// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmulatorContentClient",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "EmulatorContentClient", targets: ["EmulatorContentClient"]),
    ],
    targets: [
        .target(name: "EmulatorContentClient"),
        .testTarget(
            name: "EmulatorContentClientTests",
            dependencies: ["EmulatorContentClient"]
        ),
    ]
)
