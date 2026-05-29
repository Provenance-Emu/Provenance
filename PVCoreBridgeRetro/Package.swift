// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let HAVE_VULKAN = true

let package = Package(
    name: "PVLibRetro",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVLibRetro",
            targets: ["PVLibRetro", "libretro"]),
//        .library(
//            name: "PVLibRetro-Dynamic",
//            type: .dynamic,
//            targets: ["PVLibRetro", "libretro"]),
//        .library(
//            name: "PVLibRetro-Static",
//            type: .static,
//            targets: ["PVLibRetro", "libretro"])
    ],

    dependencies: [
        .package(path: "../PVAudio"),
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVCoreObjCBridge"),
        .package(path: "../PVEmulatorCore"),
        .package(path: "../PVJIT"),
        .package(path: "../PVLogging"),
        .package(path: "../MoltenVK"),
        .package(path: "../PVNetplay"),
        .package(path: "../PVObjCUtils"),
        .package(path: "../PVPlists"),
        .package(path: "../PVPrimitives"),
        .package(path: "../PVSettings"),
        .package(path: "../PVSupport"),
        .package(path: "../PVArchiving"),
        .package(path: "../PVRcheevos"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),
    ],

    // MARK: - Targets
    targets: [
        // ------------------- PVLibRetro Bridge -------------------
        .target(
            name: "PVLibRetro",
            dependencies: [
                "PVAudio",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVEmulatorCore",
                .product(name: "JITManager", package: "PVJIT"),
                "PVLogging",
                .product(name: "MoltenVK-1.2.8", package: "MoltenVK", condition: .when(platforms: [.iOS, .tvOS, .macOS, .macCatalyst])),
                "PVNetplay",
                "PVObjCUtils",
                "PVPlists",
                .product(name: "PVSystems", package: "PVPrimitives"),
                "PVSettings",
                "PVSupport",
                "PVArchiving",
                "libretro",
                .product(name: "CRcheevos", package: "PVRcheevos"),
            ],
            cSettings: [
                .headerSearchPath("../libretro/include"),
                .headerSearchPath("../libretro/retro/libretro-common/include"),
                .headerSearchPath("../libretro/retro/gfx/"),
                .headerSearchPath("../libretro/retro/"),
                .headerSearchPath("../../MoltenVK/MoltenVK/include"),
                // PVThinLibretroFrontend.mm uses quote-form #include "rc_client.h"
                // which clang resolves against the source file's own include
                // search paths first. CRcheevos's `publicHeadersPath: "include"`
                // exposes the headers to Swift modules but quote-form includes
                // from .mm sources don't always resolve via the SPM dep graph,
                // especially under Xcode workspace builds. Add the path explicitly.
                .headerSearchPath("../../../PVRcheevos/rcheevos/include"),
                // rc_libretro.h is a semi-private header under src/ (not include/).
                .headerSearchPath("../../../PVRcheevos/rcheevos/src"),
                .define("DEBUG", .when(configuration: .debug)),
                .define("HAVE_RCHEEVOS", to: "1"),
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
                .linkedFramework("Metal"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreMIDI", .when(platforms: [.iOS, .macOS, .macCatalyst, .visionOS])),
                .linkedFramework("Network")
            ]
        ),
        // ------------------- libretro -------------------
        .target(
            name: "libretro",
            dependencies: [
                "PVObjCUtils"
            ],
            sources: [
                "retro/libretro-common/dynamic/dylib.c",
                "retro/libretro-common/rthreads/rthreads.c",
                "retro/cores/dynamic_dummy.c",
                "retro/input/drivers/nullinput.c",
                "retro/input/input_driver.c",
                "retro/input/input_keymaps.c",
                "retro/input/input_keyboard.c",
                "retro/msg_hash.c",
                "retro/performance_counters.c",
                "retro/retro.m",
                
                
//                "retro/intl/msg_hash_us.c",
//                "retro/gfx/video_driver.c",

//                "retro/libretro-common/hash/rhash.c",
//                "retro/libretro-common/streams/file_stream.c",

            ],
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
                .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                .define("TARGET_OS_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS])),
                .define("IOS", to: "1", .when(platforms: [.iOS, .tvOS])),
            ],
            linkerSettings: [
                .linkedLibrary("iconv"),
                .linkedLibrary("z"),
            ]
        ),
        // ------------------- MoltenVK -------------------

//        .binaryTarget(name: "MoltenVK", path: "../MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework")
        // ------------------- Tests -------------------
            .testTarget(
                name: "PVLibRetroTests",
                dependencies: [
                    "PVLibRetro",
                    "libretro",
                    "PVCoreBridge",
                    "PVCoreObjCBridge",
                    "PVEmulatorCore",
                    "PVArchiving"
                ])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu2x,
    cxxLanguageStandard: .gnucxx20
)
