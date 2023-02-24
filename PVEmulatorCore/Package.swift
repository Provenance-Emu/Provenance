// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
import Foundation

#if swift(>=6.0)
var pvemulatorCoreSwiftFlags: [SwiftSetting] = [
	.define("LIBRETRO"),
	.unsafeFlags([
	  "-Xfrontend", "-enable-cxx-interop",
	  "-enable-experimental-cxx-interop"
	])
]
#else
var pvemulatorCoreSwiftFlags: [SwiftSetting] = [
	.define("LIBRETRO")
]
#endif

let package = Package(
    name: "PVEmulatorCore",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVEmulatorCore",
            targets: ["PVEmulatorCore", "PVEmulatorCoreObjC"]),
         .library(
             name: "PVEmulatorCore-Dynamic",
             type: .dynamic,
             targets: ["PVEmulatorCore", "PVEmulatorCoreObjC"]),
         .library(
             name: "PVEmulatorCore-Static",
             type: .static,
             targets: ["PVEmulatorCore", "PVEmulatorCoreObjC"])
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/"),
        .package(name: "PVAudio", path: "../PVAudio/")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVEmulatorCore
        .target(
            name: "PVEmulatorCoreObjC",
            dependencies: [
                .product(name: "PVObjCUtils", package: "PVObjCUtils"),
                .product(name: "PVSupport", package: "PVSupport"),
                .product(name: "PVLogging", package: "PVLogging"),
                .product(name: "PVAudio", package: "PVAudio")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            swiftSettings: pvemulatorCoreSwiftFlags,
            linkerSettings: [
				.linkedFramework("Metal"),
				.linkedFramework("MetalKit"),
                .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
				.linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
				.linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
				.linkedFramework("OpenGL", .when(platforms: [.macOS])),
				.linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),

        .target(
            name: "PVEmulatorCore",
            dependencies: [
                "PVEmulatorCoreObjC",
				.product(name: "PVObjCUtils", package: "PVObjCUtils"),
                .product(name: "PVSupport", package: "PVSupport"),
                .product(name: "PVAudio", package: "PVAudio"),
                .product(name: "PVLogging", package: "PVLogging")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("LIBRETRO", to: "1"),
                .headerSearchPath("include"),
                .headerSearchPath("../PVSupport/include"),
                .headerSearchPath("../PVEmulatorCoreObjC/include")
            ],
            swiftSettings: pvemulatorCoreSwiftFlags,
            linkerSettings: [
                .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ])],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx17
)

