// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVWebServerHost",
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
            name: "PVWebServerHost",
            targets: ["PVWebServerHost"]
        ),
        .library(
            name: "PVWebServerHost-Dynamic",
            type: .dynamic,
            targets: ["PVWebServerHost"]
        ),
        .library(
            name: "PVWebServerHost-Static",
            type: .static,
            targets: ["PVWebServerHost"]
        )
    ],

    dependencies: [
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(url: "https://github.com/Provenance-Emu/PVWebServer.git", from: "1.2.0")
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVWebServerHost",
            dependencies: [
                "PVLogging",
                .product(name: "PVWebServer", package: "PVWebServer")
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVWebServerHostTests",
            dependencies: ["PVWebServerHost"]
        )
    ],
    swiftLanguageModes: [.v5]
)
