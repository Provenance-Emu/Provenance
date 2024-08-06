// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let HAVE_VULKAN = true

let package = Package(
    name: "PVLibRetro",
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
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVEmulatorCore"),
        .package(path: "../PVSupport"),
        .package(path: "../PVAudio"),
        .package(path: "../PVLogging"),
        .package(path: "../PVObjCUtils"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVLibRetro
        .target(
            name: "PVLibRetro",
            dependencies: [
                "PVSupport",
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVAudio",
                "PVLogging",
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
                .define("HAVE_VULKAN", to: HAVE_VULKAN ? "1" : "0"),
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
                    .define("HAVE_VULKAN", to: HAVE_VULKAN ? "1" : "0"),
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
                    "MoltenVK",
                    "PVObjCUtils"
                ],
                sources: [
                    "audio/audio_driver.c",
                    "msg_hash.c",
                    "movie.c",
                    "performance_counters.c",
                    "verbosity.c",
                    "retro.m",
                    "gfx/video_driver.c",
                    "gfx/video_thread_wrapper.c",
                    (HAVE_VULKAN ? "gfx/drivers/vulkan.c" : nil),
//                    "dynamic.c".
                    "cores/dynamic_dummy.c",
                    "input/input_driver.c",
                    "input/input_keyboard.c",
                    "input/drivers/nullinput.c",
                    "libretro-common/rthreads/rthreads.c",
                    "libretro-common/dynamic/dylib.c",
//                    "cores/libretro-net-retropad/net_retropad_core.c"
//                    "frontend/drivers/platform_darwin.m"
//                    "audio/drivers/coreaudio.c"
//                    "ui/drivers/cocoa/cocoa_common.m"
                    "driver.c"
                ].compactMap { $0 },
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
                    .define("HAVE_VULKAN", to: HAVE_VULKAN ? "1" : "0"),
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
