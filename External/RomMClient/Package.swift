// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RomMClient",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [.library(name: "RomMClient", targets: ["RomMClient"])],
    targets: [
        .target(name: "RomMClient")
    ]
)
