// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVCoreBridge",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
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
    ],

    dependencies: [
        .package(name: "PVAudio", path: "../PVAudio/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVPlists", path: "../PVPlists/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/"),

        // MARK: Macros

        // SwiftMacros
        // https://github.com/ShenghaiWang/SwiftMacros?tab=readme-ov-file
//        .package(url: "https://github.com/JoeMatt/SwiftMacros.git", branch: "main"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVCoreBridge",
            dependencies: [
                "PVAudio",
                "PVLogging",
                "PVPlists",
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
            ]
        ),
        
        .target(
            name: "PVCoreObjCBridge",
            dependencies: [
                "PVLogging",
                "PVCoreBridge",
                "PVObjCUtils"
            ],
            cSettings: [
                .unsafeFlags(["-fmodules", "-fcxx-modules"])
            ]
        ),


        // MARK: SwiftPM tests
        .testTarget(
            name: "PVCoreBridgeTests",
            dependencies: ["PVCoreBridge"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)
