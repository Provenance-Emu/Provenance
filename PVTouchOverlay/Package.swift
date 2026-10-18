// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVTouchOverlay",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "PVTouchOverlay", targets: ["PVTouchOverlay"])
    ],
    dependencies: [
        .package(path: "../PVPrimitives"),
        .package(url: "https://github.com/Provenance-Emu/PVSystems.git", from: "1.0.0"),
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVLogging"),
        .package(path: "../PVSettings"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2")
    ],
    targets: [
        .target(
            name: "PVTouchOverlay",
            dependencies: [
                .product(name: "PVSystems", package: "PVSystems"),
                .product(name: "PVPrimitives", package: "PVPrimitives"),
                "PVCoreBridge",
                "PVLogging",
                "PVSettings",
                "Defaults"
            ]
        ),
        .testTarget(
            name: "PVTouchOverlayTests",
            dependencies: ["PVTouchOverlay", .product(name: "PVSystems", package: "PVSystems")]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
