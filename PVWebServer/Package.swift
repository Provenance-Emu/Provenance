// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVWebServer",
    defaultLocalization: .init(stringLiteral: "en"),
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
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
        // Modern HTTP/WebDAV server backend (Task A, Epic #2758)
        // Hummingbird 2.x — Swift-native, built on Swift NIO, iOS/tvOS compatible.
        // Sole HTTP/WebDAV backend, including uploader and debug API routes.
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "2.0.0"
        ),
        // Hummingbird imports ServiceContextModule without declaring it (it only declares Tracing).
        // swift-service-context 1.4.0 + swift-distributed-tracing 1.6.0 (2026-10-12) inverted that
        // pair: ServiceContextModule now depends on tracing's Instrumentation, and Tracing no longer
        // pulls ServiceContextModule into Hummingbird's build order, so an unpinned resolution fails
        // at random with "no such module 'ServiceContextModule'" (every Tuist dev-workspace build;
        // Provenance.xcworkspace is only spared by its committed Package.resolved). Cap both until
        // Hummingbird declares the dependency. Pin-only: no target of ours uses them directly.
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", "1.0.0"..<"1.6.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", "1.0.0"..<"1.4.0"),
        // Used for HTTPField / HTTPFields in PVModernWebServer (Hummingbird uses HTTPTypes internally
        // but does not re-export it to dependents).
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],

    // MARK: - Targets
    targets: [
        // Swift target: high-level manager and protocol wrappers
        .target(
            name: "PVWebServer",
            dependencies: [
                "PVLogging",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "Sources/PVWebServerSwift"
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVWebServerTests",
            dependencies: [
                "PVWebServer",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
