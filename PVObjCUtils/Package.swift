// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVObjCUtils",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVObjCUtils",
            targets: ["PVObjCUtils"]),
        .library(
            name: "PVObjCUtils-Dynamic",
            type: .dynamic,
            targets: ["PVObjCUtils"]),
        .library(
            name: "PVObjCUtils-Static",
            type: .static,
            targets: ["PVObjCUtils"])
    ],

    dependencies: [],

    // MARK: - Targets
    targets: [
        // MARK: - PVObjCUtils
        .target(
            name: "PVObjCUtils"
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
