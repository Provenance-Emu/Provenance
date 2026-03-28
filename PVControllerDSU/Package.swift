// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVControllerDSU",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "PVControllerDSU", targets: ["PVControllerDSU"])
    ],
    dependencies: [],
    targets: [
        .target(name: "PVControllerDSU"),
        .testTarget(name: "PVControllerDSUTests", dependencies: ["PVControllerDSU"])
    ],
    swiftLanguageModes: [.v5, .v6]
)
