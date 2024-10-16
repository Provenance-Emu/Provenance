// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVCoreObjCBridge",
    platforms: [
        .iOS(.v15),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVCoreObjCBridge",
            targets: ["PVCoreObjCBridge"]),
        .library(
            name: "PVCoreObjCBridge-Dynamic",
            type: .dynamic,
            targets: ["PVCoreObjCBridge"]),
        .library(
            name: "PVCoreObjCBridge-Static",
            type: .static,
            targets: ["PVCoreObjCBridge"]),
    ],

    dependencies: [
        .package(name: "PVAudio", path: "../PVAudio/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVPlists", path: "../PVPlists/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/"),
        .package(name: "PVCoreBridge", path: "../PVCoreBridge/"),
        .package(path: "../PVSettings"),

        // MARK: Macros

        // SwiftMacros
        // https://github.com/ShenghaiWang/SwiftMacros?tab=readme-ov-file
        .package(url: "https://github.com/JoeMatt/SwiftMacros.git", branch: "main"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVCoreObjCBridge",
            dependencies: [
                "PVLogging",
                "PVCoreBridge",
                "PVObjCUtils",
                "PVAudio",
                "PVSettings"
            ],
            cSettings: [
                .unsafeFlags(["-fmodules", "-fcxx-modules"])
            ]
        ),


        // MARK: SwiftPM tests
        .testTarget(
            name: "PVCoreBridgeTests",
            dependencies: ["PVCoreObjCBridge"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)
