// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "MoltenVK",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "MoltenVK",
            targets: ["MoltenVK", "MoltenVK.xcframework"]),
         .library(
             name: "MoltenVK-Dynamic",
             type: .dynamic,
             targets: ["MoltenVK", "MoltenVK.xcframework"]),
         .library(
             name: "MoltenVK-Static",
             type: .static,
             targets: ["MoltenVK-Static", "MoltenVK-Static.xcframework"])
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "MoltenVK",
            dependencies: [
                "MoltenVK.xcframework"
            ],
            path: "MoltenVK/dynamic"
        ),
        .target(
            name: "MoltenVK-Static",
            dependencies: [
                "MoltenVK-Static.xcframework"
            ],
            path: "MoltenVK/static"
        ),
        .binaryTarget(
            name: "MoltenVK.xcframework",
            path: "MoltenVK/dynamic/MoltenVK.xcframework"
        ),
        .binaryTarget(
            name: "MoltenVK-Static.xcframework",
            path: "MoltenVK/static/MoltenVK.xcframework"
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
