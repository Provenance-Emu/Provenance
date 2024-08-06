// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVWebServer",
    defaultLocalization: .init(stringLiteral: "en"),
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVWebServer",
            targets: ["PVWebServer"]
        ),
        .library(
            name: "PVWebServer-Dynamic",
            type: .dynamic,
            targets: ["PVWebServer"]
        ),
        .library(
            name: "PVWebServer-Static",
            type: .static,
            targets: ["PVWebServer"]
        )
    ],

    dependencies: [
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVWebServer",
            dependencies: [
                "PVLogging",
                "PVSupport",
                "PVObjCUtils"
			],
            resources: [
                .copy("Resources/GCDWebUploader.bundle")
            ],
            cSettings: [
                .headerSearchPath("GCDWebServer/Core/"),
                .headerSearchPath("GCDWebServer/Requests/"),
                .headerSearchPath("GCDWebServer/Responses/"),
                .headerSearchPath("GCDWebDAVServer/"),
                .headerSearchPath("GCDWebUploader/")

            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst, .visionOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVWebServerTests",
            dependencies: ["PVWebServer"])
    ],
    swiftLanguageVersions: [.v5]
)
