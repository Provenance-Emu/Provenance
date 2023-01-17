// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLibRetro",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "Retro",
            targets: ["Retro"]
        ),
         .library(
             name: "Retro-Dynamic",
             type: .dynamic,
             targets: ["Retro"]
         ),
         .library(
             name: "Retro-Static",
             type: .static,
             targets: ["Retro"]
         ),
         .library(
             name: "PVLibRetro",
             targets: ["PVLibRetro"]),
         .library(
             name: "PVLibRetro-Dynamic",
             type: .dynamic,
             targets: ["PVLibRetro"]),
         .library(
             name: "PVLibRetro-Static",
             type: .static,
             targets: ["PVLibRetro"])
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVEmulatorCore", path: "../PVEmulatorCore/")
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "Retro",
            dependencies: [],
            sources: [
                "libretro-common/rthreads/rthreads.c",
                "libretro-common/dynamic/dylib.c",
                "msg_hash.c",
                "movie.c",
                "retro.m",
                "performance_counters.c",
                "input/input_driver.c",
                "input/input_keyboard.c",
                "input/drivers/nullinput.c",
                "cores/dynamic_dummy.c"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("TARGET_OS_IPHONE", to: "1"),
                .define("HAVE_DYNAMIC", to: "1"),
                .define("HAVE_DYLIB", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_THREADS", to: "1"),
                .define("NONJAILBROKEN", to: "1"),
                .define("HAVE_THREAD_STORAGE", to: "1"),
                .define("HAVE_OPENGL", to: "1"),
                .define("HAVE_OPENGLES", to: "1"),
                .define("HAVE_OPENGLES2", to: "1"),
                .define("HAVE_OPENGLES3", to: "1"),
                .define("GLES", to: "1"),
                .define("GLES2", to: "1"),
                .define("GLES3", to: "1"),
                .define("GLES31", to: "1"),
//                .headerSearchPath("libretro-common/include"),
//                .headerSearchPath("gfx"),
//                .headerSearchPath(".")
            ],
            cxxSettings: [
                .define("TARGET_OS_IPHONE", to: "1"),
                .define("HAVE_DYNAMIC", to: "1"),
                .define("HAVE_DYLIB", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_THREADS", to: "1"),
                .define("NONJAILBROKEN", to: "1"),
                .define("HAVE_THREAD_STORAGE", to: "1"),
                .define("HAVE_OPENGL", to: "1"),
                .define("HAVE_OPENGLES", to: "1"),
                .define("HAVE_OPENGLES2", to: "1"),
                .define("HAVE_OPENGLES3", to: "1"),
                .define("GLES", to: "1"),
                .define("GLES2", to: "1"),
                .define("GLES3", to: "1"),
                .define("GLES31", to: "1"),
//                .headerSearchPath("libretro-common/include"),
//                .headerSearchPath("gfx"),
//                .headerSearchPath(".")
            ],
            swiftSettings: [
                .define("LIBRETRO"),
                .unsafeFlags(["-enable-experimental-cxx-interop"])
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),

        // TODO: This won't build yet
         .target(
             name: "PVLibRetro",
             dependencies: [
                 .product(name: "PVSupport", package: "PVSupport"),
                 .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
//                 .product(name: "PVEmulatorCoreObjC", package: "PVEmulatorCore"),
                 .product(name: "PVLogging", package: "PVLogging"),
                 "Retro"
             ],
             publicHeadersPath: "include",
             cSettings: [
                 .define("HAVE_DYNAMIC", to: "1"),
                 .define("HAVE_DYLIB", to: "1"),
                 .define("NEED_DYNAMIC", to: "1"),
                 .define("__LIBRETRO__", to: "1"),
                 .define("HAVE_THREADS", to: "1"),
                 .define("HAVE_THREAD_STORAGE", to: "1"),
                 .define("HAVE_OPENGL", to: "1"),
                 .define("HAVE_OPENGLES", to: "1"),
                 .define("HAVE_OPENGLES2", to: "1"),
                 .define("HAVE_OPENGLES3", to: "1"),
                 .define("GLES", to: "1"),
                 .define("GLES2", to: "1"),
                 .define("GLES3", to: "1"),
                 .define("GLES31", to: "1"),
                 .headerSearchPath("include"),
                 .headerSearchPath("../Retro/"),
                 .headerSearchPath("../Retro/libretro-common/include"),
                 .headerSearchPath("../Retro/gfx")
             ],
             linkerSettings: [
                 .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                 .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
                 .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
             ]),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLibRetroTests",
            dependencies: ["PVLibRetro"])
    ],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx17
)
