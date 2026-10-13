// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Targets and their settings are built up as typed constants: one giant `Package(...)`
// literal with inline `+` concatenations made the manifest type-check time out.

// MARK: ------- Core --------

// Module is PVGenesis so Core.plist's principal class `PVGenesis.PVCoreGenesisPlus`
// resolves in both the xcodeproj and the SwiftPM build.
let coreTarget: Target = .target(
    name: "PVGenesis",
    dependencies: [
        "PVEmulatorCore",
        "PVCoreBridge",
        "PVLogging",
        "PVAudio",
        "PVSupport",
        // Used directly (CorePlist, SystemIdentifier, settings); a dynamic product links only
        // what its target declares, so these can't ride in on PVEmulatorCore's closure.
        "PVPlists",
        "PVPrimitives",
        "PVSettings",
        "PVCoreGenesisPlusBridge",
        .product(name: "PVRcheevos", package: "PVRcheevos"),
        .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
    ],
    path: "Sources/PVCoreGenesisPlus",
    resources: [
        .process("Resources/Core.plist")
    ],
    cSettings: GenesisSettings.defines
)

// MARK: ------- Bridge --------

let bridgeExtraSettings: [CSetting] = [
    // The bridge picks `@import libgenesisplus` over the framework's -Swift.h.
    .define("SWIFT_MODULE", to: "1"),
    .define("HAVE_COCOATOUCH", to: "1"),
    .headerSearchPath("../libgenesisplus/libretro"),
    .headerSearchPath("../libgenesisplus/other"),
]
let bridgeSettings: [CSetting] = GenesisSettings.defines
    + bridgeExtraSettings
    + GenesisSettings.headerPaths(prefix: "../libgenesisplus/")

let bridgeTarget: Target = .target(
    name: "PVCoreGenesisPlusBridge",
    dependencies: [
        "PVEmulatorCore",
        "PVCoreBridge",
        "PVCoreObjCBridge",
        "PVSupport",
        "PVObjCUtils",
        "PVLogging",
        "PVAudio",
        "libgenesisplus"
    ],
    publicHeadersPath: "include",
    cSettings: bridgeSettings
)

// MARK: ------- libgenesisplus --------

let libgenesisExtraSettings: [CSetting] = [
    .headerSearchPath("libretro"),
    .headerSearchPath("other"),
    // zstd 1.5.6 ships lib/module.modulemap, so under -fmodules `zstd.h` is imported as the
    // `libzstd` module and the `#define ZSTD_STATIC_LINKING_ONLY` in zstd's own sources has no
    // effect ("has no effect on the import of 'libzstd'"). Define it on the command line.
    .define("ZSTD_STATIC_LINKING_ONLY"),
]
let libgenesisSettings: [CSetting] = GenesisSettings.defines
    + libgenesisExtraSettings
    + GenesisSettings.headerPaths(prefix: "")

let libgenesisTarget: Target = .target(
    name: "libgenesisplus",
    exclude: [
        "other"
    ],
    sources: Sources.libgenesis,
    packageAccess: true,
    cSettings: libgenesisSettings,
    linkerSettings: [
        .linkedLibrary("z")
    ]
)

let package = Package(
    name: "PVCoreGenesisPlus",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVCoreGenesisPlus",
            targets: ["PVGenesis"]),
        .library(
            name: "PVCoreGenesisPlus-Dynamic",
            type: .dynamic,
            targets: ["PVGenesis"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),
        .package(path: "../../PVPlists"),
        .package(name: "PVPrimitives", path: "../../PVPrimitives/"),
        .package(path: "../../PVSettings"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),

    ],
    targets: [coreTarget, bridgeTarget, libgenesisTarget],
    swiftLanguageVersions: [.v5], // v6 strict concurrency rejects the options table (nonisolated static state)
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)

/// Preprocessor defines copied from Config.xcconfig and PVGenesis.xcodeproj OTHER_CFLAGS.
enum GenesisSettings {
    static let defines: [CSetting] = [
        .define("NS_BLOCK_ASSERTIONS", to: "1"),
        .define("LSB_FIRST"),
        .define("HAVE_ZLIB"),
        .define("Z7_ST"),
        .define("ZSTD_DISABLE_ASM"),
        .define("USE_32BPP_RENDERING"),
        .define("__LIBRETRO__"),
        .define("HAVE_OVERCLOCK"),
        .define("HAVE_OPLL_CORE"),
        .define("HAVE_YM3438_CORE"),
        .define("INLINE", to: "static inline"),
        .define("Z80_OVERCLOCK_SHIFT", to: "20"),
        .define("M68K_OVERCLOCK_SHIFT", to: "20"),
        .define("USE_LIBCHDR", to: "1"),
        .define("HAVE_LROUND"),
        .define("NDEBUG", .when(configuration: .release)),
    ]

    /// HEADER_SEARCH_PATHS from PVGenesis.xcodeproj, relative to a target directory under `Sources/`.
    static func headerPaths(prefix: String) -> [CSetting] {
        let core = prefix + "Genesis-Plus-GX/core"
        let chdr = core + "/cd_hw/libchdr"
        return [
        core,
        core + "/z80",
        core + "/m68k",
        core + "/ntsc",
        core + "/sound",
        core + "/sound/minimp3",
        core + "/input_hw",
        core + "/cd_hw",
        core + "/cart_hw",
        core + "/cart_hw/svp",
        chdr + "/include",
        chdr + "/src",
        chdr + "/deps/lzma-24.05/include",
        chdr + "/deps/zstd-1.5.6/lib",
        ].map { .headerSearchPath($0) }
    }
}

enum Sources {
    /// The core files PVGenesis.xcodeproj compiles from the fork, plus libchdr and its
    /// lzma/zstd dependencies and the locally maintained libretro front.
    static let libgenesis: [String] = {
        let core = [
            "core/cart_hw/areplay.c",
            "core/cart_hw/eeprom_93c.c",
            "core/cart_hw/eeprom_i2c.c",
            "core/cart_hw/eeprom_spi.c",
            "core/cart_hw/flash_cfi.c",
            "core/cart_hw/ggenie.c",
            "core/cart_hw/md_cart.c",
            "core/cart_hw/megasd.c",
            "core/cart_hw/sms_cart.c",
            "core/cart_hw/sram.c",
            "core/cart_hw/svp/ssp16.c",
            "core/cart_hw/svp/svp.c",
            "core/cart_hw/yx5200.c",
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
            "core/input_hw/smash.c",
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
        ]
        let chdr = "core/cd_hw/libchdr"
        let deps = [
            "src/libchdr_bitstream.c",
            "src/libchdr_cdrom.c",
            "src/libchdr_chd.c",
            "src/libchdr_flac.c",
            "src/libchdr_huffman.c",
            "deps/lzma-24.05/src/CpuArch.c",
            "deps/lzma-24.05/src/LzFind.c",
            "deps/lzma-24.05/src/LzmaDec.c",
            "deps/lzma-24.05/src/LzmaEnc.c",
            "deps/zstd-1.5.6/lib/common/entropy_common.c",
            "deps/zstd-1.5.6/lib/common/error_private.c",
            "deps/zstd-1.5.6/lib/common/fse_decompress.c",
            "deps/zstd-1.5.6/lib/common/xxhash.c",
            "deps/zstd-1.5.6/lib/common/zstd_common.c",
            "deps/zstd-1.5.6/lib/decompress/huf_decompress.c",
            "deps/zstd-1.5.6/lib/decompress/zstd_ddict.c",
            "deps/zstd-1.5.6/lib/decompress/zstd_decompress.c",
            "deps/zstd-1.5.6/lib/decompress/zstd_decompress_block.c",
        ].map { "\(chdr)/\($0)" }
        return (core + deps).map { "Genesis-Plus-GX/\($0)" } + [
            "libretro/libretro.c",
            "libretro/scrc32.c",
        ]
    }()
}
