// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVArchiving",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "PVArchiving", targets: ["PVArchiving"]),
        .library(name: "PVArchivingFormats", targets: ["PVArchivingFormats"]),
    ],
    dependencies: [
        .package(path: "../PVLogging"),
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", exact: "2.4.3"),
        .package(url: "https://github.com/OlehKulykov/PLzmaSDK.git", revision: "1.2.5"),
        .package(name: "SWCompression", path: "../Dependencies/SWCompression"),
        .package(url: "https://github.com/mtgto/Unrar.swift.git", .upToNextMajor(from: "0.3.16")),
        .package(name: "LzhArchive", path: "../Dependencies/LzhArchive"),
    ],
    targets: [
        // Lightweight types-only target: enums, errors, protocols.
        // Zero third-party deps — anything that just needs to classify
        // files by archive format can depend on this without pulling in
        // 5 compression libraries.
        .target(
            name: "PVArchivingFormats",
            dependencies: [],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        // Full extraction/compression engine.
        .target(
            name: "PVArchiving",
            dependencies: [
                "PVArchivingFormats",
                "PVLogging",
                .product(name: "PLzmaSDK", package: "PLzmaSDK"),
                .product(name: "SWCompression", package: "SWCompression"),
                .product(name: "Unrar", package: "Unrar.swift"),
                .product(name: "ZipArchive", package: "ZipArchive"),
                "LzhArchive",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        .testTarget(
            name: "PVArchivingTests",
            dependencies: ["PVArchiving"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        // Tests for the types-only target. Kept separate from PVArchivingTests
        // so they inherit PVArchivingFormats' zero third-party dependencies and
        // stay runnable via a plain `swift test`.
        .testTarget(
            name: "PVArchivingFormatsTests",
            dependencies: ["PVArchivingFormats"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx20
)
