// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "MoltenVK",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MoltenVK-1.2.8",
            targets: ["MoltenVK-1.2.8", "MoltenVK-1.2.8.xcframework"]),
        .library(name: "MoltenVK-Catalyst",
                 targets: ["MoltenVK-Catalyst.xcframework"]),
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
            name: "MoltenVK-1.2.8",
            dependencies: [
                "MoltenVK-1.2.8.xcframework"
            ],
            path: "MoltenVK-1.2.8/dynamic"
        ),
        .target(
            name: "MoltenVK-Static",
            dependencies: [
                "MoltenVK-Static.xcframework"
            ],
            path: "MoltenVK/static"
        ),
//        .target(
//            name: "MoltenVK-Catalyst",
//            dependencies: [
//                "MoltenVK-Catalyst.xcframework"
//            ],
//            path: "MoltenVK/dynamic/dylib/macOS/"),
        /// Catalyst framework
        /// Note: dylibs aren't supported
        /// need to make a .framework with Scripts/dylibsToFramework.sh
        /// then make an XCFramework with
        ///  xcodebuild -create-xcframework -framework MoltenVK-Catalyst.framework -output MoltenVK-Catalyst.
        .binaryTarget(
            name: "MoltenVK-Catalyst.xcframework",
            path: "MoltenVK/dynamic/dylib/macOS/MoltenVK-Catalyst.xcframework"),
        /// Multi-platform dynamic XCFramework
        .binaryTarget(
            name: "MoltenVK.xcframework",
            path: "MoltenVK/dynamic/MoltenVK.xcframework"),
        /// Multi-platform static XCFramework
        .binaryTarget(
            name: "MoltenVK-Static.xcframework",
            path: "MoltenVK/static/MoltenVK.xcframework"),
        .binaryTarget(
            name: "MoltenVK-1.2.8.xcframework",
            path: "MoltenVK/dynamic/MoltenVK-1.2.8.xcframework"),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
