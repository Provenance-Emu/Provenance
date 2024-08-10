// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVAudio",
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
            resources: [.copy("PrivacyInfo.xcprivacy")]
        )
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
