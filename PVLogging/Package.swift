// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

#if os(Linux)
let loggingProductTargets: [String] = ["PVLogging"]
let extraProducts: [Product] = []
let extraTargets: [Target] = []
#else
let loggingProductTargets: [String] = ["PVLogging", "PVLoggingObjC"]
let extraProducts: [Product] = [
    .library(
        name: "PVLoggingObjC",
        targets: ["PVLogging", "PVLoggingObjC"]),
]
let extraTargets: [Target] = [
    .target(
        name: "PVLoggingObjC",
        dependencies: [
            "PVLogging"
        ],
        publicHeadersPath: "include/"
    ),
]
#endif

let package = Package(
    name: "PVLogging",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVLogging",
            targets: loggingProductTargets),
        .library(
            name: "PVLogging-Dynamic",
            type: .dynamic,
            targets: loggingProductTargets),
        .library(
            name: "PVLogging-Static",
            type: .static,
            targets: loggingProductTargets),
    ] + extraProducts,
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "PVLogging",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLoggingTests",
            dependencies: ["PVLogging"],
            path: "Tests")
    ] + extraTargets,
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx20
)
