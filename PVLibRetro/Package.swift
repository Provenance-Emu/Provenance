// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLibRetro",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVLibRetro",
            targets: ["PVLibRetro"]),
//        .library(
//            name: "PVLibRetro-Dynamic",
//            type: .dynamic,
//            targets: ["PVLibRetro"]),
        .library(
            name: "PVLibRetro-Static",
            type: .static,
            targets: ["PVLibRetro"])

    ],

    dependencies: [
        .package(
            name: "PVSupport",
            path: "../PVSupport/"),
        .package(
            name: "PVEmulatorCore",
            path: "../PVEmulatorCore/"),
        .package(
            name: "PVObjCUtils",
            path: "../PVObjCUtils/"),
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVLibRetro
        .target(
            name: "PVLibRetro",
            dependencies: [
                "PVSupport",
                "PVEmulatorCore",
                "retro",
                "PVLibRetroSwift",
                "PVObjCUtils",
                "MoltenVK"
            ],
            cSettings: [
                .headerSearchPath("../retro/libretro-common/include"),
                .headerSearchPath("../retro/gfx/"),
                .headerSearchPath("../retro/"),
                .headerSearchPath("../../MoltenVK/MoltenVK/include"),
                .define("DEBUG", .when(configuration: .debug)),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_THREADS", to: "1"),
                .define("HAVE_OPENGL", to: "1"),
                .define("HAVE_OPENGLES", to: "1"),
                .define("HAVE_OPENGLES2", to: "1"),
                .define("HAVE_OPENGLES3", to: "1"),
                .define("HAVE_DYNAMIC", to: "1"),
                .define("HAVE_DYLIB", to: "1"),
                .define("HAVE_OPENGLES31", to: "1"),
//                .define("HAVE_VULKAN", to: "1"),
                .define("GLES", to: "1"),
                .define("GLES2", to: "1"),
                .define("GLES3", to: "1"),
                .define("GLES31", to: "1"),
                .define("GLES_SILENCE_DEPRECATION", to: "1"),
                .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                //.define("TARGET_IPHONE_SIMULATOR", .when(platforms: [.iOS, .tvOS])),
            ],
            linkerSettings: [
                .linkedFramework("OpenGL", .when(platforms: [.macOS, .macCatalyst])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .linkedFramework("Metal")
            ]
        ),

            .target(
                name: "PVLibRetroSwift",
                dependencies: [
                    "PVSupport",
                    "PVEmulatorCore",
                    "retro"
                ],
                cSettings: [
                    .headerSearchPath("../retro/libretro-common/include"),
                    .headerSearchPath("../retro/gfx/"),
                    .headerSearchPath("../retro/"),
                    .define("DEBUG", .when(configuration: .debug)),
                    .define("__LIBRETRO__", to: "1"),
                    .define("HAVE_THREADS", to: "1"),
                    .define("HAVE_OPENGL", to: "1"),
                    .define("HAVE_OPENGLES", to: "1"),
                    .define("HAVE_OPENGLES2", to: "1"),
                    .define("HAVE_OPENGLES3", to: "1"),
                    .define("HAVE_DYNAMIC", to: "1"),
                    .define("HAVE_DYLIB", to: "1"),
                    .define("HAVE_OPENGLES31", to: "1"),
//                    .define("HAVE_VULKAN", to: "1"),
                    .define("GLES", to: "1"),
                    .define("GLES2", to: "1"),
                    .define("GLES3", to: "1"),
                    .define("GLES31", to: "1"),
                    .define("GLES_SILENCE_DEPRECATION", to: "1"),
                    .define("NEED_DYNAMIC", to: "1"),
                    .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                    //.define("TARGET_IPHONE_SIMULATOR", .when(platforms: [.iOS, .tvOS])),
                ]
            ),

            .target(
                name: "retro",
                dependencies: [
                    "MoltenVK"
                ],
                sources: [
                    "msg_hash.c",
                    "movie.c",
                    "performance_counters.c",
                    "verbosity.c",
                    "retro.m",
                    "gfx/video_driver.c",
//                    "gfx/drivers/vulkan.c",
//                    "dynamic.c".
                    "cores/dynamic_dummy.c",
                    "input/input_driver.c",
                    "input/input_keyboard.c",
                    "input/drivers/nullinput.c",
                    "libretro-common/rthreads/rthreads.c",
                    "libretro-common/dynamic/dylib.c"
//                    "cores/libretro-net-retropad/net_retropad_core.c"
//                    "frontend/drivers/platform_darwin.m"
//                    "audio/drivers/coreaudio.c"
//                    "ui/drivers/cocoa/cocoa_common.m"
                ],
                publicHeadersPath: "include",
                cSettings: [
                    .headerSearchPath("./libretro-common/include"),
                    .headerSearchPath("./retro/gfx/"),
                    .headerSearchPath("./retro/"),
                    .headerSearchPath("../../MoltenVK/MoltenVK/include"),
                    .define("DEBUG", .when(configuration: .debug)),
                    .define("__LIBRETRO__", to: "1"),
                    .define("HAVE_THREADS", to: "1"),
                    .define("HAVE_OPENGL", to: "1"),
                    .define("HAVE_OPENGLES", to: "1"),
                    .define("HAVE_OPENGLES2", to: "1"),
                    .define("HAVE_OPENGLES3", to: "1"),
                    .define("HAVE_DYNAMIC", to: "1"),
                    .define("HAVE_DYLIB", to: "1"),
                    .define("HAVE_OPENGLES31", to: "1"),
//                    .define("HAVE_VULKAN", to: "1"),
                    .define("GLES", to: "1"),
                    .define("GLES2", to: "1"),
                    .define("GLES3", to: "1"),
                    .define("GLES31", to: "1"),
                    .define("GLES_SILENCE_DEPRECATION", to: "1"),
                    .define("NEED_DYNAMIC", to: "1"),
                    .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                    .define("TARGET_OS_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                    .define("IOS", to: "1", .when(platforms: [.iOS, .tvOS])),
                ]
            ),
        .binaryTarget(name: "MoltenVK", path: "../MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework")
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu2x,
    cxxLanguageStandard: .gnucxx20
)
