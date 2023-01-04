// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSupport",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVSupport",
            type: .dynamic,
            targets: ["PVSupport", "PVSupportObjC"]),
        .library(
            name: "PVEmulatorCore",
            type: .dynamic,
            targets: ["PVEmulatorCoreObjC"]),
        .library(
            name: "PVLibRetro",
            type: .dynamic,
            targets: ["PVLibRetro"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVLogging", path: "../PVLogging/")
    ],
    targets: [
        .target(
            name: "PVSupportObjC",
            dependencies: ["PVSupport"],
            path: "Sources/PVSupport/ObjC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),

        .target(
            name: "PVSupport",
            dependencies: [
                .productItem(name: "PVLogging", package: "PVLogging"),
            ],
            path: "Sources/PVSupport/Swift",
            resources: [
                .process("Controller/AHAP/")
            ],
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),
        
        .target(
            name: "PVEmulatorCoreObjC",
            dependencies: [
                "PVSupport",
                "PVSupportObjC"
            ],
            path: "Sources/PVEmulatorCore/ObjC",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("PVSupport/Swift/include"),
            ],
            linkerSettings: [
                .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),

        .target(
            name: "PVEmulatorCore",
            dependencies: [
                "PVEmulatorCoreObjC"
            ],
            path: "Sources/PVEmulatorCore/Swift",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../PVSupport/Swift/include"),
            ],
            linkerSettings: [
                .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),
        
        .target(
            name: "Retro",
            dependencies: [],
            path: "Sources/retro/",
            sources: [
                "libretro-common/rthreads/rthreads.c",
                "libretro-common/dynamic/dylib.c",
                "msg_hash.c",
                "movie.c",
                "retro.m",
                "performance_counters.c",
                "input/input_driver.c",
                "input/input_keyboard.c",
                "input/nullinput.c",
                "cores/dynamic_dummy.c",
            ],
            publicHeadersPath: "libretro-common/include",
            cSettings: [
//                .define("HAVE_CONFIG_H", to:"1"),
                .define("HAVE_DYNAMIC", to:"1"),
                .define("HAVE_DYLIB", to:"1"),
                .define("NEED_DYNAMIC", to:"1"),
                .define("__LIBRETRO__", to:"1"),
                .define("HAVE_THREADS", to:"1"),
                .define("NONJAILBROKEN", to:"1"),
                .define("HAVE_THREAD_STORAGE", to:"1"),
                .define("HAVE_OPENGL", to:"1"),
                .define("HAVE_OPENGLES", to:"1"),
                .define("HAVE_OPENGLES2", to:"1"),
                .define("HAVE_OPENGLES3", to:"1"),
                .define("GLES", to:"1"),
                .define("GLES2", to:"1"),
                .define("GLES3", to:"1"),
                .define("GLES31", to:"1"),
                .headerSearchPath("include"),
                .headerSearchPath("../retro/libretro-common/include"),
                .headerSearchPath("../retro/gfx"),
                .headerSearchPath("../retro/"),
                .headerSearchPath("PVSupport/Swift/include"),
            ],
            linkerSettings: [
                .linkedFramework("objc", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),
        // TODO: This won't build yet
        .target(
            name: "PVLibRetro",
            dependencies: ["PVSupport", "PVSupportObjC", "PVEmulatorCore", "PVEmulatorCoreObjC", "Retro"],
            path: "Sources/PVLibRetro/",
            publicHeadersPath: "include",
            cSettings: [
                .define("HAVE_DYNAMIC", to:"1"),
                .define("HAVE_DYLIB", to:"1"),
                .define("NEED_DYNAMIC", to:"1"),
                .define("__LIBRETRO__", to:"1"),
                .define("HAVE_THREADS", to:"1"),
                .define("HAVE_THREAD_STORAGE", to:"1"),
                .define("HAVE_OPENGL", to:"1"),
                .define("HAVE_OPENGLES", to:"1"),
                .define("HAVE_OPENGLES2", to:"1"),
                .define("HAVE_OPENGLES3", to:"1"),
                .define("GLES", to:"1"),
                .define("GLES2", to:"1"),
                .define("GLES3", to:"1"),
                .define("GLES31", to:"1"),
                .headerSearchPath("include"),
                .headerSearchPath("../retro/"),
                .headerSearchPath("../retro/libretro-common/include"),
                .headerSearchPath("../retro/gfx"),
                .headerSearchPath("PVSupport/Swift/include"),
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),

        // MARK: SwiftPM tests
        // .testTarget(
        //     name: "PVSupportTests",
        //     dependencies: ["PVSupport"])
    ]
)
