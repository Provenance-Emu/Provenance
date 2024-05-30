// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVCoreBridge",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "PVCoreBridge",
            targets: ["PVCoreBridge"]),
        .library(
            name: "PVCoreBridge-Dynamic",
            type: .dynamic,
            targets: ["PVCoreBridge"]),
        .library(
            name: "PVCoreBridge-Static",
            type: .static,
            targets: ["PVCoreBridge"]),
    ],

    dependencies: [
        .package(name: "PVAudio", path: "../PVAudio/"),
        .package(name: "PVLogging", path: "../PVLogging/")
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVCoreBridge",
            dependencies: [
                "PVAudio",
                "PVLogging"
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVCoreBridgeTests",
            dependencies: ["PVCoreBridge"]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)
