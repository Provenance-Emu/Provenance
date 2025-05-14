// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

#if swift(>=5.9)
var pvemulatorCoreSwiftFlags: [SwiftSetting] = [
    .define("GL_SILENCE_DEPRECATION"),
    .define("GLES_SILENCE_DEPRECATION"),
    .define("CI_SILENCE_GL_DEPRECATION"),
    .interoperabilityMode(.C)
]
#else
var pvemulatorCoreSwiftFlags: [SwiftSetting] = [
    .define("GL_SILENCE_DEPRECATION"),
    .define("GLES_SILENCE_DEPRECATION"),
    .define("CI_SILENCE_GL_DEPRECATION")
]
#endif

let package = Package(
    name: "PVEmulatorCore",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v12),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVEmulatorCore",
            targets: ["PVEmulatorCore"]),
         .library(
             name: "PVEmulatorCore-Dynamic",
             type: .dynamic,
             targets: ["PVEmulatorCore"]),
         .library(
             name: "PVEmulatorCore-Static",
             type: .static,
             targets: ["PVEmulatorCore"]),
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVCoreBridge", path: "../PVCoreBridge/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVAudio", path: "../PVAudio/"),
        .package(name: "PVPrimitives", path: "../PVPrimitives/")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVEmulatorCore
        .target(
            name: "PVEmulatorCore",
            dependencies: [
                "PVCoreBridge",
                "PVPrimitives",
                .product(name: "PVSupport", package: "PVSupport"),
                .product(name: "PVLogging", package: "PVLogging"),
                .product(name: "PVAudio", package: "PVAudio")
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: [
                .define("GL_SILENCE_DEPRECATION",
                        .when(platforms: [.macOS, .macCatalyst])),
                .define("GLES_SILENCE_DEPRECATION",
                        .when(platforms: [.iOS, .tvOS, .watchOS, .macCatalyst])),
                .define("CI_SILENCE_GL_DEPRECATION")
            ],
            swiftSettings: pvemulatorCoreSwiftFlags,
            linkerSettings: [
                .linkedFramework("Metal", .when(platforms: [.iOS, .tvOS, .macOS, .macCatalyst])),
				.linkedFramework("MetalKit", .when(platforms: [.iOS, .tvOS, .macOS, .macCatalyst])),
                .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
				.linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("OpenGL", .when(platforms: [.macOS])),
				.linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVEmulatorCoreTests",
            dependencies: ["PVEmulatorCore"]
        )
    ],
    swiftLanguageModes: [.v6],
    cLanguageStandard: .gnu2x,
    cxxLanguageStandard: .gnucxx20
)
