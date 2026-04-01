// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVCoreBridge",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v12),
        .macCatalyst(.v17),
        .visionOS(.v1)
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
        // ObjC-compatible forward declarations — import in .h files
        .library(
            name: "PVCoreBridgeTypes",
            targets: ["PVCoreBridgeTypes"]),
    ],

    dependencies: [
        .package(name: "PVAudio", path: "../PVAudio/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVPlists", path: "../PVPlists/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/"),
        .package(name: "PVPrimitives", path: "../PVPrimitives/"),
        .package(name: "PVSettings", path: "../PVSettings/"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2"),

        // MARK: Macros

        // SwiftMacros
        // https://github.com/ShenghaiWang/SwiftMacros?tab=readme-ov-file
//        .package(url: "https://github.com/JoeMatt/SwiftMacros.git", from: "1.0.1"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVCoreBridge",
            dependencies: [
                "PVAudio",
                "PVLogging",
                "PVPlists",
                "PVObjCUtils",
                "PVPrimitives",
                "PVSettings",
                "Defaults"
        //                "SwiftMacros"
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: [
                .define("GL_SILENCE_DEPRECATION", to: "1"),
                .define("GLES_SILENCE_DEPRECATION", to: "1"),
                .define("CI_SILENCE_GL_DEPRECATION", to: "1")
            ],
            swiftSettings: [
                .define("USE_OPENGL", .when(platforms: [.macCatalyst, .macOS])),
                .define("USE_OPENGLES", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("USE_METAL", .when(platforms: [.macCatalyst, .macOS])),
                .define("USE_EFFECT", .when(platforms: [.iOS, .tvOS, .visionOS, .macCatalyst])),
                .define("GL_SILENCE_DEPRECATION"),
                .define("GLES_SILENCE_DEPRECATION"),
                .define("CI_SILENCE_GL_DEPRECATION")
            ],
            linkerSettings: [
                // CoreMIDI is available on iOS, tvOS, macOS, Catalyst, and visionOS.
                // watchOS does not ship CoreMIDI; all usage is guarded with
                // `#if canImport(CoreMIDI)` in source files.
                .linkedFramework("CoreMIDI",
                    .when(platforms: [.iOS, .tvOS, .macOS, .macCatalyst, .visionOS]))
            ]
        ),
        
//        .target(
//            name: "PVCoreObjCBridge",
//            dependencies: [
//                "PVLogging",
//                "PVCoreBridge",
//                "PVObjCUtils"
//            ],
//            cSettings: [
//                .unsafeFlags(["-fmodules", "-fcxx-modules"])
//            ]
//        ),


        // Pure ObjC header target — forward-declares all @objc types from PVCoreBridge.
        // ObjC .h files can `#import <PVCoreBridgeTypes/PVCoreBridgeTypes.h>` or `@import PVCoreBridgeTypes;`
        // then `@import PVCoreBridge;` in .m/.mm files for full definitions.
        .target(
            name: "PVCoreBridgeTypes",
            dependencies: [],
            publicHeadersPath: "include"
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVCoreBridgeTests",
            dependencies: [
                "PVCoreBridge",
                "PVPrimitives",
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)
