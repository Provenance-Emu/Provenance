// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVVisualBoyAdvance",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVVisualBoyAdvance",
            targets: ["PVVisualBoyAdvance", "PVVisualBoyAdvanceSwift"]),
        .library(
            name: "PVVisualBoyAdvance-Dynamic",
            type: .dynamic,
            targets: ["PVVisualBoyAdvance", "PVVisualBoyAdvanceSwift"]),
        .library(
            name: "PVVisualBoyAdvance-Static",
            type: .static,
            targets: ["PVVisualBoyAdvance", "PVVisualBoyAdvanceSwift"]),

    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils")
    ],
    targets: [
        .target(
            name: "PVVisualBoyAdvance",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVVisualBoyAdvanceSwift",
                //                "PVVisualBoyAdvanceC",
                "libvisualboyadvance",
            ],
            resources: [
                .process("Resources/Core.plist"),
                .copy("Resources/vba-over.ini")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),

                .headerSearchPath("../libvisualboyadvance/include/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/apu"),
                .headerSearchPath("../libvisualboyadvance/GBACore/common"),
                .headerSearchPath("../libvisualboyadvance/GBACore/gba"),
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ]),

                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libvisualboyadvance/include/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/apu"),
                .headerSearchPath("../libvisualboyadvance/GBACore/common"),
                .headerSearchPath("../libvisualboyadvance/GBACore/gba"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "PVVisualBoyAdvanceSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libvisualboyadvance",
                //                "PVVisualBoyAdvanceC"
            ],
            cSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libvisualboyadvance/include/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/apu"),
                .headerSearchPath("../libvisualboyadvance/GBACore/common"),
                .headerSearchPath("../libvisualboyadvance/GBACore/gba"),
            ],
            cxxSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                    .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libvisualboyadvance/include/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/"),
                .headerSearchPath("../libvisualboyadvance/GBACore/apu"),
                .headerSearchPath("../libvisualboyadvance/GBACore/common"),
                .headerSearchPath("../libvisualboyadvance/GBACore/gba"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

    //        .target(
    //            name: "PVVisualBoyAdvanceC",
    //            dependencies: [
    //                "libvisualboyadvance",
    //            ],
    //            publicHeadersPath: "./",
    //            cSettings: [
    //                .define("INLINE", to: "inline"),
    //                .define("USE_STRUCTS", to: "1"),
    //                .define("__LIBRETRO__", to: "1"),
    //                .define("HAVE_COCOATOJUCH", to: "1"),
    //                .define("__GCCUNIX__", to: "1"),
    //                .headerSearchPath("../libvisualboyadvance/include/"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/apu"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/common"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/gba"),
    //            ],
    //            cxxSettings: [
    //                .define("INLINE", to: "inline"),
    //                .define("USE_STRUCTS", to: "1"),
    //                .define("__LIBRETRO__", to: "1"),
    //                .define("HAVE_COCOATOJUCH", to: "1"),
    //                .define("__GCCUNIX__", to: "1"),
    //                .headerSearchPath("../libvisualboyadvance/include/"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/apu"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/common"),
    //                .headerSearchPath("../libvisualboyadvance/GBACore/gba"),
    //            ]
    //        ),

        .target(
            name: "libvisualboyadvance",
            sources: [
                "GBACore/apu/Blip_Buffer.cpp",
                "GBACore/apu/Effects_Buffer.cpp",
                "GBACore/apu/Gb_Apu.cpp",
                "GBACore/apu/Gb_Apu_State.cpp",
                "GBACore/apu/Gb_Oscs.cpp",
                "GBACore/apu/Multi_Buffer.cpp",
                "GBACore/common/memgzio.c",
                "GBACore/gba/agbprint.cpp",
                "GBACore/gba/armdis.cpp",
                "GBACore/gba/bios.cpp",
                "GBACore/gba/Cheats.cpp",
                "GBACore/gba/CheatSearch.cpp",
                "GBACore/gba/EEprom.cpp",
                "GBACore/gba/elf.cpp",
                "GBACore/gba/Flash.cpp",
                "GBACore/gba/GBA-arm.cpp",
                "GBACore/gba/GBA-thumb.cpp",
                "GBACore/gba/GBA.cpp",
                "GBACore/gba/gbafilter.cpp",
                "GBACore/gba/GBAGfx.cpp",
                "GBACore/gba/GBALink.cpp",
                "GBACore/gba/GBASockClient.cpp",
                "GBACore/gba/Globals.cpp",
                "GBACore/gba/Mode0.cpp",
                "GBACore/gba/Mode1.cpp",
                "GBACore/gba/Mode2.cpp",
                "GBACore/gba/Mode3.cpp",
                "GBACore/gba/Mode4.cpp",
                "GBACore/gba/Mode5.cpp",
                "GBACore/gba/RTC.cpp",
                "GBACore/gba/Sound.cpp",
                "GBACore/gba/Sram.cpp",
                "GBACore/Util.cpp",
            ],
            packageAccess: true,
            cSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                    .define("__GCCUNIX__", to: "1"),
//                .define("__LIB_RETRO__", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),

                    .headerSearchPath("include/"),
                .headerSearchPath("GBACore/"),
                .headerSearchPath("GBACore/apu"),
                .headerSearchPath("GBACore/common"),
                .headerSearchPath("GBACore/gba"),
            ],
            cxxSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                    .define("__GCCUNIX__", to: "1"),
//                .define("__LIB_RETRO__", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),

                    .headerSearchPath("include/"),
                .headerSearchPath("GBACore/"),
                .headerSearchPath("GBACore/apu"),
                .headerSearchPath("GBACore/common"),
                .headerSearchPath("GBACore/gba"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)
