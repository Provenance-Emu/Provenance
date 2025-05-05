// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVPrimitives",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v12),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVPrimitives",
            targets: ["PVPrimitives", "PVSystems"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            name: "PVSupport",
            path: "../PVSupport"
        ),
        .package(
            name: "PVLogging",
            path: "../PVLogging"
        ),
        .package(
            name: "PVHashing",
            path: "../PVHashing"
        )
    ],

    targets: [
        .target(
            name: "PVPrimitives",
            dependencies: ["PVSupport", "PVLogging", "PVHashing"]
        ),
        // MARK: ------------ Systems ------------
        .target(
            name: "PVSystems",
            dependencies: ["PVSupport", "PVLogging", "PVHashing"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
