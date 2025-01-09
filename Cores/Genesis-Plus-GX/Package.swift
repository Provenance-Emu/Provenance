// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVCoreGenesisPlus",
    platforms: [
        .iOS(.v17),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVCoreGenesisPlus",
            targets: ["PVCoreGenesisPlus"]),
        .library(
            name: "PVCoreGenesisPlus-Dynamic",
            type: .dynamic,
            targets: ["PVCoreGenesisPlus"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),

    ],
    targets: [
        
        // MARK: ------- Core --------
        
        .target(
            name: "PVCoreGenesisPlus",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVCoreGenesisPlusBridge",
                "libgenesisplus",
            ],
            cSettings: [
                .define("NS_BLOCK_ASSERTIONS", to: "1"),
                .define("LSB_FIRST"),
                .define("HAVE_ZLIB"),
                .define("USE_32BPP_RENDERING"),
                .define("NDEBUG", .when(configuration: .release)),
                .define("DHAVE_OVERCLOCK"),
                .define("DHAVE_OPLL_CORE"),
                .define("DHAVE_YM3438_CORE"),
                .define("DZ80_OVERCLOCK_SHIFT", to: "20"),
                .define("DM68K_OVERCLOCK_SHIFT", to: "20"),
                
                    .define("INLINE", to: "static inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                
                .headerSearchPath("../libretro-np2kai/src"),
                .headerSearchPath("../libretro-np2kai/src/m68000"),
                .headerSearchPath("../libretro-np2kai/libretro-common"),
                .headerSearchPath("../libretro-np2kai/libretro-common/include"),
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        
        // MARK: ------- Bridge --------
        .target(
            name: "PVCoreGenesisPlusBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVLogging",
                "libgenesisplus"
            ],
            cSettings: [
                .define("NS_BLOCK_ASSERTIONS", to: "1"),
                .define("LSB_FIRST"),
                .define("HAVE_ZLIB"),
                .define("USE_32BPP_RENDERING"),
                .define("NDEBUG", .when(configuration: .release)),
                .define("DHAVE_OVERCLOCK"),
                .define("DHAVE_OPLL_CORE"),
                .define("DHAVE_YM3438_CORE"),
                .define("DZ80_OVERCLOCK_SHIFT", to: "20"),
                .define("DM68K_OVERCLOCK_SHIFT", to: "20"),
                
                .define("INLINE", to: "static inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                
                .headerSearchPath("../libgenesisplus/Genesis-Plus-GX/libretro/"),
                .headerSearchPath("../libgenesisplus/Genesis-Plus-GX/libretro/libretro-common/include"),

                .headerSearchPath("../libgenesisplus/Genesis-Plus-GX/core/"),
                .headerSearchPath("../libgenesisplus/Genesis-Plus-GX/m68k/"),

                .headerSearchPath("../libgenesisplus/Genesis-Plus-GX/libretro/"),
            ]
        ),
        
        // MARK: ------- libgenesisplus --------
        
            .target(
                name: "libgenesisplus",
                exclude: [
                    "genplusgx_source",
                    "other"
                ],
                sources: Sources.libgenesis,
                packageAccess: true,
                cSettings: [
                    .headerSearchPath("Genesis-Plus-GX/core/"),
                    .headerSearchPath("Genesis-Plus-GX/core/cart_hw/"),
                    .headerSearchPath("Genesis-Plus-GX/core/cart_hw/svp"),
                    .headerSearchPath("Genesis-Plus-GX/core/cd_hw/"),
                    .headerSearchPath("Genesis-Plus-GX/core/input_hw/"),
                    .headerSearchPath("Genesis-Plus-GX/core/m68k/"),
                    .headerSearchPath("Genesis-Plus-GX/core/ntsc/"),
                    .headerSearchPath("Genesis-Plus-GX/core/sound/"),
                    .headerSearchPath("Genesis-Plus-GX/core/tremor/"),
                    .headerSearchPath("Genesis-Plus-GX/core/z80/"),
                    .headerSearchPath("Genesis-Plus-GX/libretro/"),
                    .headerSearchPath("Genesis-Plus-GX/libretro/libretro-common/"),
                    .headerSearchPath("Genesis-Plus-GX/libretro/libretro-common/include/"),
                    .headerSearchPath("libretro/"),
                    .headerSearchPath("other/"),
                    .headerSearchPath("include/Genesis-Plus-GX/"),
                    .headerSearchPath("include/libretro/"),
                    .headerSearchPath("include/libretro-common/"),
                    
                    .define("NS_BLOCK_ASSERTIONS", to: "1"),
                    .define("LSB_FIRST"),
                    .define("HAVE_ZLIB"),
                    .define("USE_32BPP_RENDERING"),
                    .define("NDEBUG", .when(configuration: .release)),
                    .define("DHAVE_OVERCLOCK"),
                    .define("DHAVE_OPLL_CORE"),
                    .define("DHAVE_YM3438_CORE"),
                    .define("DZ80_OVERCLOCK_SHIFT", to: "20"),
                    .define("DM68K_OVERCLOCK_SHIFT", to: "20"),
                    
                    .define("INLINE", to: "static inline"),
                    .define("USE_STRUCTS", to: "1"),
                    .define("__LIBRETRO__", to: "1"),
                    .define("__GCCUNIX__", to: "1"),
                ]
            ),
        
        //        .target(
        //            name: "libgenesisplus-legacy",
        //            path: "Sources/libgenesisplus",
        //            exclude: [
        //                "Genesis-Plus-GX/",
        //                "other"
        //            ],
        //            sources: Sources.libgenesisplus-legacy,
        //            publicHeadersPath: "include/genplusgx_source",
        //            packageAccess: true,
        //            cSettings: [
        //                .define("NS_BLOCK_ASSERTIONS", to: "1"),
        //                .define("LSB_FIRST"),
        //                .define("HAVE_ZLIB"),
        //                .define("USE_32BPP_RENDERING"),
        //                .define("NDEBUG", .when(configuration: .release)),
        //                .define("DHAVE_OVERCLOCK"),
        //                .define("DHAVE_OPLL_CORE"),
        //                .define("DHAVE_YM3438_CORE"),
        //                .define("DZ80_OVERCLOCK_SHIFT", to: "20"),
        //                .define("DM68K_OVERCLOCK_SHIFT", to: "20"),
        //
        //                .define("INLINE", to: "static inline"),
        //                .define("USE_STRUCTS", to: "1"),
        //                .define("__LIBRETRO__", to: "1"),
        //                .define("__GCCUNIX__", to: "1")
        //            ]
        //        )
    ],
    swiftLanguageVersions: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)

enum Sources {
    static let libgenesis: [String] = [
        "core/cart_hw/areplay.c",
        "core/cart_hw/eeprom_93c.c",
        "core/cart_hw/eeprom_i2c.c",
        "core/cart_hw/eeprom_spi.c",
        "core/cart_hw/ggenie.c",
        "core/cart_hw/md_cart.c",
        "core/cart_hw/megasd.c",
        "core/cart_hw/sms_cart.c",
        "core/cart_hw/sram.c",
        "core/cart_hw/svp/ssp16.c",
        "core/cart_hw/svp/svp.c",
        "core/cd_hw/cd_cart.c",
        "core/cd_hw/cdc.c",
        "core/cd_hw/cdd.c",
        "core/cd_hw/gfx.c",
        "core/cd_hw/pcm.c",
        "core/cd_hw/scd.c",
        "core/genesis.c",
        "core/input_hw/activator.c",
        "core/input_hw/gamepad.c",
        "core/input_hw/graphic_board.c",
        "core/input_hw/input.c",
        "core/input_hw/lightgun.c",
        "core/input_hw/mouse.c",
        "core/input_hw/paddle.c",
        "core/input_hw/sportspad.c",
        "core/input_hw/teamplayer.c",
        "core/input_hw/terebi_oekaki.c",
        "core/input_hw/xe_1ap.c",
        "core/io_ctrl.c",
        "core/loadrom.c",
        "core/m68k/m68kcpu.c",
        "core/m68k/s68kcpu.c",
        "core/mem68k.c",
        "core/membnk.c",
        "core/memz80.c",
        "core/ntsc/md_ntsc.c",
        "core/ntsc/sms_ntsc.c",
        "core/sound/blip_buf.c",
        "core/sound/eq.c",
        "core/sound/opll.c",
        "core/sound/psg.c",
        "core/sound/sound.c",
        "core/sound/ym2413.c",
        "core/sound/ym2612.c",
        "core/sound/ym3438.c",
        "core/state.c",
        "core/system.c",
        "core/vdp_ctrl.c",
        "core/vdp_render.c",
        "core/z80/z80.c",
        "libretro/libretro.c",
        "libretro/scrc32.c",
    ].map { "Genesis-Plus-GX/\($0)"}
    
    static let libgenesisplus_legacy: [String] = [
        "genplusgx_source/cart_hw/areplay.c",
        "genplusgx_source/cart_hw/eeprom_93c.c",
        "genplusgx_source/cart_hw/eeprom_i2c.c",
        "genplusgx_source/cart_hw/eeprom_spi.c",
        "genplusgx_source/cart_hw/ggenie.c",
        "genplusgx_source/cart_hw/md_cart.c",
        "genplusgx_source/cart_hw/sms_cart.c",
        "genplusgx_source/cart_hw/sram.c",
        "genplusgx_source/cart_hw/svp/ssp16.c",
        "genplusgx_source/cart_hw/svp/svp.c",
        "genplusgx_source/cd_hw/cd_cart.c",
        "genplusgx_source/cd_hw/cdc.c",
        "genplusgx_source/cd_hw/cdd.c",
        "genplusgx_source/cd_hw/gfx.c",
        "genplusgx_source/cd_hw/pcm.c",
        "genplusgx_source/cd_hw/scd.c",
        "genplusgx_source/genesis.c",
        "genplusgx_source/input_hw/activator.c",
        "genplusgx_source/input_hw/gamepad.c",
        "genplusgx_source/input_hw/graphic_board.c",
        "genplusgx_source/input_hw/input.c",
        "genplusgx_source/input_hw/lightgun.c",
        "genplusgx_source/input_hw/mouse.c",
        "genplusgx_source/input_hw/paddle.c",
        "genplusgx_source/input_hw/sportspad.c",
        "genplusgx_source/input_hw/teamplayer.c",
        "genplusgx_source/input_hw/terebi_oekaki.c",
        "genplusgx_source/input_hw/xe_1ap.c",
        "genplusgx_source/io_ctrl.c",
        "genplusgx_source/loadrom.c",
        "genplusgx_source/m68k/m68kcpu.c",
        "genplusgx_source/m68k/s68kcpu.c",
        "genplusgx_source/mem68k.c",
        "genplusgx_source/membnk.c",
        "genplusgx_source/memz80.c",
        "genplusgx_source/ntsc/md_ntsc.c",
        "genplusgx_source/ntsc/sms_ntsc.c",
        "genplusgx_source/sound/blip_buf.c",
        "genplusgx_source/sound/eq.c",
        "genplusgx_source/sound/opll.c",
        "genplusgx_source/sound/psg.c",
        "genplusgx_source/sound/sound.c",
        "genplusgx_source/sound/ym2413.c",
        "genplusgx_source/sound/ym2612.c",
        "genplusgx_source/sound/ym3438.c",
        "genplusgx_source/state.c",
        "genplusgx_source/system.c",
        "genplusgx_source/vdp_ctrl.c",
        "genplusgx_source/vdp_render.c",
        "genplusgx_source/z80/z80.c",
        "libretro/libretro.c",
        "libretro/scrc32.c"
    ]
}

