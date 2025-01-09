// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum Sources {
    static let libtic80: [String] = [
      
    ]

    static let libretro_common: [String] = [
//        "encodings/encoding_utf.c",
//        "file/file_path.c",
//        "file/file_path_io.c",
//        "streams/file_stream.c",
//        "streams/file_stream_transforms.c",
//        "string/stdstring.c",
//        "time/rtime.c",
//        "vfs/vfs_implementation.c"
    ]
}

let package = Package(
    name: "PVVTIC80",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVVTIC80",
            targets: ["PVVTIC80", "PVVTIC80Swift"]),
        .library(
            name: "PVVTIC80-Dynamic",
            type: .dynamic,
            targets: ["PVVTIC80", "PVVTIC80Swift"]),
        .library(
            name: "PVVTIC80-Static",
            type: .static,
            targets: ["PVVTIC80", "PVVTIC80Swift"]),

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

        // MARK: --------- PVVTIC80 ---------- //

        .target(
            name: "PVVTIC80",
            dependencies: [
                "libtic80",
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVPlists",
                "PVObjCUtils",
                "PVVTIC80C"
//                "PVVTIC80Swift"
            ],
            path: "VirtualJaguar",
            resources: [
                .process("Resources/Core.plist")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../virtualjaguar-libretro/src"),
                .headerSearchPath("../virtualjaguar-libretro/src/m68000"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common/include"),
            ]
        ),

        // MARK: --------- PVVTIC80Swift ---------- //

        .target(
            name: "VirtualJaguarSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libtic80",
                "PVVTIC80C",
                "PVVTIC80"
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../virtualjaguar-libretro/src"),
                .headerSearchPath("../virtualjaguar-libretro/src/m68000"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common/include"),
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),

        // MARK: --------- PVVTIC80C ---------- //

        .target(
            name: "PVVTIC80C",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libtic80"
            ],
            path: "VirtualJaguarC",
            publicHeadersPath: "./",
            packageAccess: true,
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../virtualjaguar-libretro/src"),
                .headerSearchPath("../virtualjaguar-libretro/src/m68000"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common/include"),
            ]
        ),

        // MARK: --------- libtic80 ---------- //

        .target(
            name: "libtic80",
            dependencies: ["libretro-common"],
            path: "virtualjaguar-libretro/src",
            exclude: [
            ],
            sources: Sources.libtic80,
            //                ,Sources.libretro_common.map { "libretro-common/\($0)" }].flatMap { $0 },
            publicHeadersPath: "./",
            packageAccess: true,
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("virtualjaguar-libretro/src"),
                .headerSearchPath("src"),
                .headerSearchPath("libretro-common/include")
            ]
        ),

        // MARK: --------- libtic80 > libretro-common ---------- //

        .target(
            name: "libretro-common",
            path: "virtualjaguar-libretro/libretro-common",
            exclude: [
                "include/vfs/vfs_implementation_cdrom.h"
            ],
            sources: [
                "encodings/encoding_utf.c",
                "file/file_path.c",
                "file/file_path_io.c",
                "streams/file_stream.c",
                "streams/file_stream_transforms.c",
                "string/stdstring.c",
                "time/rtime.c",
                "vfs/vfs_implementation.c"
            ],
            publicHeadersPath: "include.spm",
            packageAccess: false,
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("./"),
                .headerSearchPath("./include"),
            ]
        ),
        // MARK: Tests
        .testTarget(
            name: "PVVTIC80Tests",
            dependencies: [
                "PVVTIC80Swift",
                "PVCoreBridge",
                "PVEmulatorCore",
                "PVVTIC80"
            ],
            resources: [
                .copy("VirtualJaguarTests/Resources/jag_240p_test_suite_v0.5.1.jag")
            ])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
