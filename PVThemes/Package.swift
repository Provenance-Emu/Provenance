// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVThemes",
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
            name: "PVThemes",
            targets: ["PVThemes"]),
         .library(
             name: "PVThemes-Dynamic",
             type: .dynamic,
             targets: ["PVThemes"]),
         .library(
             name: "PVThemes-Static",
             type: .static,
             targets: ["PVThemes"])
    ],

    dependencies: [
        /// Macros

        /// https://github.com/alvmo/HexColors
        .package(url: "https://github.com/alvmo/HexColors.git", from: "1.0.0"),
        .package(url: "https://github.com/ShenghaiWang/SwiftMacros.git", from: "1.0.0")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVThemes
        .target(
            name: "PVThemes",
            dependencies: [
                .product(name: "HexColors", package: "HexColors"),
                .product(name: "SwiftMacros", package: "SwiftMacros")
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("SwiftUI")
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "PVThemesTests",
            dependencies: [
                "PVThemes"
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
