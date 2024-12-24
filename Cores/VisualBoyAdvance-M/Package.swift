// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let HAVE_COCOATOUCH = "1"
let INLINE = "inline"
let NO_ZIP = "0"
let USE_STRUCTS = "1"
let __GCCUNIX__ = "1"
let __LIBRETRO__ = "0"

let package = Package(
    name: "PVCoreVisualBoyAdvance",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVVisualBoyAdvance",
            targets: ["PVVisualBoyAdvance"]),
        .library(
            name: "PVVisualBoyAdvance-Dynamic",
            type: .dynamic,
            targets: ["PVVisualBoyAdvance"]),
        .library(
            name: "PVVisualBoyAdvance-Static",
            type: .static,
            targets: ["PVVisualBoyAdvance"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        // MARK: --------- Core -----------
        .target(
            name: "PVVisualBoyAdvance",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVVisualBoyAdvanceBridge",
                "PVVisualBoyAdvanceOptions",
                "libvisualboyadvance",
            ],
            resources: [
                .process("Resources/Core.plist"),
            ],
            cSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
            ],
            cxxSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        // MARK: --------- Bridge -----------
        .target(
            name: "PVVisualBoyAdvanceBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVPlists",
                "PVObjCUtils",
                "PVVisualBoyAdvanceOptions",
                "libvisualboyadvance",
            ],
            resources: [
                .copy("Resources/vba-over.ini")
            ],
            cSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),
                .define("USE_STRUCTS", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .define("__LIBRETRO__", to: __LIBRETRO__),
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
//                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("HAVE_COCOATOUCH", to: "1"),
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
        // MARK: --------- Options -----------
        .target(
            name: "PVVisualBoyAdvanceOptions",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVPlists",
                "PVObjCUtils",
            ]
        ),
        // MARK: --------- libvisualboyadvance -----------
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
//                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("HAVE_COCOATOUCH", to: "1"),
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

                .define("HAVE_COCOATOUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .define("__LIBRETRO__", to: __LIBRETRO__),

                .headerSearchPath("include/"),
                .headerSearchPath("GBACore/"),
                .headerSearchPath("GBACore/apu"),
                .headerSearchPath("GBACore/common"),
                .headerSearchPath("GBACore/gba"),
            ]
        ),
        // MARK: --------- Tests -----------
        .testTarget(
            name: "PVVisualBoyAdvanceTests",
            dependencies: ["PVVisualBoyAdvance"],
            cSettings: [
                .define("C_CORE"),
                .define("FINAL_VERSION"),
                .define("NO_LINK"),
                .define("NO_PNG"),
                .define("TILED_RENDERING"),

                .define("__GCCUNIX__", to: "1"),
//                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),

                .headerSearchPath("include/"),
                .headerSearchPath("GBACore/"),
                .headerSearchPath("GBACore/apu"),
                .headerSearchPath("GBACore/common"),
                .headerSearchPath("GBACore/gba"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .c99,
    cxxLanguageStandard: .gnucxx17
)
