// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVApp",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVApp",
            targets: ["PVApp"]
        ),
        .library(
            name: "PVApp-Dynamic",
            type: .dynamic,
            targets: ["PVApp"]
        ),
        .library(
            name: "PVApp-Static",
            type: .static,
            targets: ["PVApp"]
        )
    ],

    dependencies: [
        .package(url: "https://github.com/RxSwiftCommunity/RxDataSources.git",
                 .upToNextMajor(from: "5.0.0")),
        .package(name: "PVLibrary", path: "../PVLibrary/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVApp",
            dependencies: [
                "PVSupport",
                "RxDataSources",
                "PVLibrary",
                "PVLogging"],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),
        // MARK: SwiftPM tests
        .testTarget(
            name: "PVAppTests",
            dependencies: ["PVApp"])
    ]
//    cLanguageStandard: .c17,
//    cxxLanguageStandard: .cxx17
)
