// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVStella",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVStella",
            targets: ["PVStella", "PVStellaSwift"]),
        .library(
            name: "PVStella-Dynamic",
            type: .dynamic,
            targets: ["PVStella", "PVStellaSwift"]),
        .library(
            name: "PVStella-Static",
            type: .static,
            targets: ["PVStella", "PVStellaSwift"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        .target(
            name: "PVStella",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVPlists",
                "PVObjCUtils",
                "PVStellaSwift",
                "PVStellaCPP",
                "libstella",
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ]),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "PVStellaSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libstella",
                "PVStellaCPP"
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            plugins: [
                // Disabled until SwiftGenPlugin support Swift 6 concurrency
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),

        .target(
            name: "PVStellaCPP",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libstella",
            ],
            publicHeadersPath: "./",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ])
            ]
        ),

        .target(
            name: "libstella",
            exclude: [
                "stella/debian/",
                "stella/docs/",
                "stella/test/",
                "stella/src/debugger/",
                "stella/src/emucore/exception",
                "stella/src/emucore/OSystemStandalone.cxx",
                "stella/src/lib/",
                "stella/src/os/macos/",
                "stella/src/os/unix/",
                "stella/src/os/libretro/jni/",
                "stella/src/os/windows/",
                "stella/src/cheat/CheatCodeDialog.cxx",
                "stella/src/common/EventHandlerSDL2.cxx",
                "stella/src/common/FBBackendSDL2.cxx",
                "stella/src/common/FBSurfaceSDL2.cxx",
                "stella/src/common/HighScoresManager.cxx",
                "stella/src/common/main.cxx",
                "stella/src/common/PNGLibrary.cxx",
                "stella/src/common/SoundSDL2.cxx",
                "stella/src/common/ThreadDebugging.cxx",
                "stella/src/common/audio/",
                "stella/src/common/repository/sqlite/",
                "stella/src/common/sdl_blitter/",
                "stella/src/gui/",
                "stella/src/tools/"
            ],
            publicHeadersPath: "include",
            packageAccess: true,
            cSettings: [
                .define("__VEC4_OPT"),
                .define("__NEON_OPT"),
                .define("LSB_FIRST", to: "1"),
                .define("HAVE_MKDIR", to: "1"),
                .define("SIZEOF_DOUBLE", to: "8"),
                .define("PSS_STYLE", to: "1"),
                .define("MPC_FIXED_POINT"),
                .define("ARCH_X86"),
                .define("WANT_STELLA_EMU", to: "1"),
                .define("STDC_HEADERS", to: "1"),
                .define("HAVE_INTTYPES", to: "1"),
                .define("Keyboard", to: "StellaKeyboard"),
                .define("_GLIBCXX_USE_CXX11_ABI", to: "1"),
                .define("UNIX", to: "1"),
                .define("DARWIN", to: "1"),
                .define("MACOS_KEYS", to: "1"),
                .define("SOUND_SUPPORT", to: "1"),
                .define("JOYSTICK_SUPPORT"),
                .define("CHEATCODE_SUPPORT"),
                .define("ARM"),
                .define("IOS"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("__LIB_RETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("NEON", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .headerSearchPath("stella/src/common/"),
                .headerSearchPath("stella/src/emucore/"),
                .headerSearchPath("stella/src/emucore/common/"),
                .headerSearchPath("stella/src/emucore/tia/"),
                .headerSearchPath("stella/src/lib/"),
                .headerSearchPath("stella/src/os/libretro/"),
                .unsafeFlags([
                    "-fno-strict-overflow",
                    "-ffast-math",
                    "-funroll-loops",
                    "-fPIC",
                    "-Wno-multichar",
                    "-Wunused",
                    "-fno-aligned-allocation"
                ]),
                .unsafeFlags([
                    "-flto"
                ], .when(configuration: .release))
            ],
            cxxSettings: [
                .define("LSB_FIRST", to: "1"),
                .define("HAVE_MKDIR", to: "1"),
                .define("SIZEOF_DOUBLE", to: "8"),
                .define("PSS_STYLE", to: "1"),
                .define("MPC_FIXED_POINT"),
                .define("ARCH_X86"),
                .define("WANT_STELLA_EMU", to: "1"),
                .define("STDC_HEADERS", to: "1"),
                .define("HAVE_INTTYPES", to: "1"),
                .define("Keyboard", to: "StellaKeyboard"),
                .define("_GLIBCXX_USE_CXX11_ABI", to: "1"),
                .define("UNIX", to: "1"),
                .define("DARWIN", to: "1"),
                .define("MACOS_KEYS", to: "1"),
                .define("SOUND_SUPPORT", to: "1"),
                .define("JOYSTICK_SUPPORT"),
                .define("CHEATCODE_SUPPORT"),
                .define("ARM"),
                .define("IOS"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("__LIB_RETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("TARGET_IPHONE", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("NEON", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .headerSearchPath("stella/src/cheat/"),
                .headerSearchPath("stella/src/common/"),
                .headerSearchPath("stella/src/common/audio"),
                .headerSearchPath("stella/src/common/repository"),
                .headerSearchPath("stella/src/common/sdl_blitter"),
                .headerSearchPath("stella/src/common/tv_filters"),
                .headerSearchPath("stella/src/emucore/"),
                .headerSearchPath("stella/src/emucore/common/"),
                .headerSearchPath("stella/src/emucore/tia/"),
                .headerSearchPath("stella/src/emucore/tia/frame-manager/"),
                .headerSearchPath("stella/src/lib/"),
                .headerSearchPath("stella/src/lib/httplib"),
                .headerSearchPath("stella/src/lib/json"),
                .headerSearchPath("stella/src/lib/libpng"),
                .headerSearchPath("stella/src/lib/nanojpeg"),
                .headerSearchPath("stella/src/lib/sqlite"),
                .headerSearchPath("stella/src/lib/tinyexif"),
                .headerSearchPath("stella/src/lib/zlib"),
                .headerSearchPath("stella/src/os/libretro/"),
                .unsafeFlags([
                    "-Wno-multichar",
                    "-Wunused",
                    "-Woverloaded-virtual",
                    "-Wnon-virtual-dtor",
                ]),
                .unsafeFlags([
                    "-flto",
                    "-fno-rtti",
                    "-Wno-poison-system-directories"
                ], .when(configuration: .release))
            ]
        ),

        // MARK: Tests
        .testTarget(name: "PVStellaTests",
                    dependencies: ["PVStella"],
                    swiftSettings: [
                        .interoperabilityMode(.Cxx)
                    ])
    ],
    swiftLanguageVersions: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)
