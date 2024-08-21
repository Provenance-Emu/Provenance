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
            targets: ["PVLibRetro", "libretro"]),
        .library(
            name: "PVLibRetro-Dynamic",
            type: .dynamic,
            targets: ["PVLibRetro", "libretro"]),
        .library(
            name: "PVLibRetro-Static",
            type: .static,
            targets: ["PVLibRetro", "libretro"])
    ],

    dependencies: [
        .package(path: "../PVAudio"),
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVEmulatorCore"),
        .package(path: "../PVLogging"),
        .package(path: "../PVObjCUtils"),
        .package(path: "../PVPlists"),
        .package(path: "../PVSettings"),
        .package(path: "../PVSupport"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVLibRetro
        .target(
            name: "PVLibRetro",
            dependencies: [
//                "MoltenVK",
                "PVAudio",
                "PVCoreBridge",
                "PVEmulatorCore",
//                "PVLibRetroSwift",
                "PVLogging",
                "PVObjCUtils",
                "PVPlists",
                "PVSettings",
                "PVSupport",
                "libretro",
            ],
            cSettings: [
                .headerSearchPath("../libretro/include"),
                .headerSearchPath("../libretro/retro/libretro-common/include"),
                .headerSearchPath("../libretro/retro/gfx/"),
                .headerSearchPath("../libretro/retro/"),
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
            swiftSettings: [
                .define("HAVE_DYNAMIC")
            ],
            linkerSettings: [
                .linkedFramework("OpenGL", .when(platforms: [.macOS, .macCatalyst])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .linkedFramework("Metal")
            ]
        ),

//            .target(
//                name: "PVLibRetroSwift",
//                dependencies: [
//                    "PVSupport",
//                    "PVEmulatorCore",
//                    "PVCoreBridge",
//                    "libretro"
//                ],
//                cSettings: [
//                    .headerSearchPath("../libretro/include"),
//                    .headerSearchPath("../libretro/retro/libretro-common/include"),
//                    .headerSearchPath("../libretro/retro/gfx/"),
//                    .headerSearchPath("../libretro/retro/"),
//                    .headerSearchPath("../../MoltenVK/MoltenVK/include"),
//                    .define("DEBUG", .when(configuration: .debug)),
//                    .define("__LIBRETRO__", to: "1"),
//                    .define("HAVE_THREADS", to: "1"),
//                    .define("HAVE_OPENGL", to: "1"),
//                    .define("HAVE_OPENGLES", to: "1"),
//                    .define("HAVE_OPENGLES2", to: "1"),
//                    .define("HAVE_OPENGLES3", to: "1"),
//                    .define("HAVE_DYNAMIC", to: "1"),
//                    .define("HAVE_DYLIB", to: "1"),
//                    .define("HAVE_OPENGLES31", to: "1"),
//                    .define("HAVE_VULKAN", to: HAVE_VULKAN ? "1" : "0"),
//                    .define("GLES", to: "1"),
//                    .define("GLES2", to: "1"),
//                    .define("GLES3", to: "1"),
//                    .define("GLES31", to: "1"),
//                    .define("GLES_SILENCE_DEPRECATION", to: "1"),
//                    .define("HAVE_DYNAMIC", to: "1"),
//                    .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
//                    //.define("TARGET_IPHONE_SIMULATOR", .when(platforms: [.iOS, .tvOS])),
//                ],
//                swiftSettings: [
//                    .define("HAVE_DYNAMIC")
//                ]
//            ),

            .target(
                name: "libretro",
                dependencies: [
//                    "MoltenVK",
                    "PVObjCUtils"
                ],
                sources: [
                    "retro/libretro-common/dynamic/dylib.c",
                    "retro/libretro-common/rthreads/rthreads.c",
                    "retro/cores/dynamic_dummy.c",
                    "retro/input/drivers/nullinput.c",
                    "retro/input/input_driver.c",
                    "retro/input/input_keyboard.c",
                    "retro/msg_hash.c",
                    "retro/performance_counters.c",
                    "retro/retro.m"
                ],
                publicHeadersPath: "include",
                cSettings: [
                    .headerSearchPath("./retro/"),
                    .headerSearchPath("./retro/gfx/"),
                    .headerSearchPath("./retro/libretro-common/include/"),

                    .headerSearchPath("../../MoltenVK/MoltenVK/include"),

                    .define("DEBUG", .when(configuration: .debug)),
                    .define("NDEBUG", .when(configuration: .release)),

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
                    .define("HAVE_DYNAMIC", to: "1"),
                    .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                    .define("TARGET_OS_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                    .define("IOS", to: "1", .when(platforms: [.iOS, .tvOS])),
                ]
            ),
//        .binaryTarget(name: "MoltenVK", path: "../MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework")
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu2x,
    cxxLanguageStandard: .gnucxx20
)
