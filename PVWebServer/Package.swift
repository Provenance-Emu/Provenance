// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVWebServer",
    defaultLocalization: .init(stringLiteral: "en"),
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
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
        // Modern HTTP/WebDAV server backend (Task A, Epic #2758)
        // Hummingbird 2.x — Swift-native, built on Swift NIO, iOS/tvOS compatible.
        // Used by PVModernWebServer when the `modernWebServer` feature flag is on.
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "2.0.0"
        ),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVWebServer",
            dependencies: [
                "PVLogging",
                "PVSupport",
                "PVObjCUtils",
                .product(name: "Hummingbird", package: "hummingbird"),
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
            dependencies: [
                "PVWebServer",
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
