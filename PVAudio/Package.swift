// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVAudio",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "PVAudio",
            targets: ["PVAudio"]),
         .library(
             name: "PVAudio-Dynamic",
             type: .dynamic,
             targets: ["PVAudio"]),
         .library(
             name: "PVAudio-Static",
             type: .static,
             targets: ["PVAudio"])
    ],

    dependencies: [
        .package(name: "PVLogging", path: "../PVLogging/")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVAudio
        .target(
            name: "PVAudio",
            dependencies: [
                .product(name: "PVLogging", package: "PVLogging")
            ],
            exclude: [
                "Legacy/"
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
