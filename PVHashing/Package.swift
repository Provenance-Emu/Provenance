// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVHashing",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "PVHashing",
            targets: ["PVHashing"]
        )
    ],
    dependencies: [
//        .package(url: "https://github.com/rnine/Checksum.git", from: "1.0.2")
        .package(url: "https://github.com/JoeMatt/Checksum.git", from: "1.1.1")
    ],
    targets: [
        .target(
            name: "PVHashing",
            dependencies: [ "Checksum" ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVHashingTests",
            dependencies: ["PVHashing"],
            resources: [ .copy("Resources/testFile.txt") ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx20
)
