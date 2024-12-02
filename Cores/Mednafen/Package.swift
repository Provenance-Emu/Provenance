// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Note: See Mednafen's `configure.ac` for information
/// on various flags and what they do

let GCC_PREPROCESSOR_DEFINITIONS: [CSetting] = [
    .define("HAVE_LROUND"),
    .define("HAVE_MKDIR"),
    .define("HAVE_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP"),
    .define("HAVE_STRINGS_H"),
    .define("HAVE_STDINT_H"),
    .define("HAVE_STDLIB_H"),
    .define("HAVE_SYS_PARAM_H"),
    .define("HAVE_UNISTD_H"),
    .define("LSB_FIRST"),
    .define("MPC_FIXED_POINT"),
    .define("STDC_HEADERS", to: "1"),
    .define("WANT_APPLE2_EMU"),
    .define("WANT_GB_EMU"),
    .define("WANT_GBA_EMU"),
    .define("WANT_LYNX_EMU"),
    .define("WANT_NES_EMU"),
    
//    .define("WANT_NES_NEW_EMU"), // experimental, alternate new(ish) NES emulation
    .define("WANT_NGP_EMU"),
    .define("WANT_PCE_EMU"),
    .define("WANT_PCE_FAST_EMU"),
    .define("WANT_PCFX_EMU"),
    .define("WANT_PSX_EMU"),
//    .define("WANT_SASPLAY_EMU"),
    .define("WANT_SNES_EMU"),
    .define("WANT_SNES_FAUST_EMU"),
    .define("WANT_SS_EMU"),
    .define("WANT_SSFPLAY_EMU"),
    .define("WANT_VB_EMU"),
    .define("WANT_WSWAN_EMU"),
    .define("WANT_STEREO_SOUND"),
//    .define("WANT_INTERNAL_CJK", to: "1"), // compiling with internal CJK fonts.
    .define("WANT_FANCY_SCALERS", to: "1"), // fancy CPU-intensive software video scalers.
//    .define("WANT_DEBUGGER", to: "1", .when(configuration: .debug)),
    .define("__LIBRETRO__"),
    .define("PSS_STYLE", to: "1"),
    .define("SIZEOF_CHAR", to: "1"),
    .define("SIZEOF_DOUBLE", to: "8"),
    .define("SIZEOF_INT", to: "4"),
    .define("SIZEOF_LONG", to: "8"),
    .define("SIZEOF_LONG_LONG", to: "8"),
    .define("SIZEOF_OFF_T", to: "8"),
    .define("SIZEOF_PTRDIFF_T", to: "8"),
    .define("SIZEOF_SHORT", to: "2"),
    .define("SIZEOF_SIZE_T", to: "8"),
    .define("SIZEOF_VOID_P", to: "8"),
    .define("__STDC_LIMIT_MACROS", to: "1")
]

let OTHER_CFLAGS: [CSetting] = [
    .unsafeFlags([
//        "-funroll-loops",
//        "-fPIC",
//        "-fno-printf-return-value",
        "-fstrict-aliasing",
//        "-fno-ipa-icf",
        "-fno-unsafe-math-optimizations",
        "-fno-fast-math", // fast-math feature on certain older versions of gcc produces horribly broken code(and even when it's working correctly, it can have somewhat unpredictable effects).
        "-fomit-frame-pointer", // is required for some x86 inline assembly to compile
        "-fsigned-char",
        "-Wall",
        "-Wno-sign-compare",
        "-Wno-unused-variable",
        "-Wno-unused-function",
        "-Wno-uninitialized",
//        "-Wno-strict-aliasing",
        "-Wshadow",
        "-Wempty-body",
        "-Wignored-qualifiers",
        "-Wvla",
        "-Wvariadic-macros",
        "-Wdisabled-optimization",
        "-fmodules",
        "-fvisibility=default"
//        "-fvisibility-inlines-hidden"
    ])]

let CSETTINGS: [CSetting] = [
//    .define("MEDNAFEN_VERSION_NUMERIC", to: "0x00103201"),
//    .define("MEDNAFEN_VERSION", to: "1.32.1"),
//    .define("PACKAGE", to: "mednafen"),
//    .define("INLINE", to: "inline"),
    .define("MDFN_PSS_STYLE", to: "1"),
    .define("HAVE_CONFIG_H", to: "1"),
    .define("HAVE_FORK", to: "1", .when(platforms: [.iOS, .macOS, .watchOS, .macCatalyst, .visionOS])),
    
//    .define("MDFN_ENABLE_DEV_BUILD", .when(configuration: .debug)),
    .define("DEBUG", to: "1", .when(configuration: .debug)),
    .define("NDEBUG", to: "1", .when(configuration: .release)),

    .headerSearchPath("../../include"),
    .headerSearchPath("../../include_mednafen")
] + GCC_PREPROCESSOR_DEFINITIONS + OTHER_CFLAGS

let MEDNAFEN_C_SETTINGS: [CSetting] = [
    .headerSearchPath("./mednafen/include_mednafen"),
    .headerSearchPath("./mednafen/include"),
    .headerSearchPath("./mednafen/")
] + CSETTINGS

func mednafenTarget(name: String, dependencies: [String] = [], path: String, sources: [String]? = nil) -> PackageDescription.Target {
    return .target(
        name: name,
        dependencies: dependencies.map{ PackageDescription.Target.Dependency(stringLiteral: $0) },
        path: "Sources/\(name)",
        sources: sources,
        cSettings: CSETTINGS)
}

let package = Package(
    name: "PVCoreMednafen",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PVCoreMednafen",
            targets: ["MednafenGameCore"]),
        // TODO: Fix MDFN_HIDE hiding symbols in dynamic builds
        .library(
            name: "PVCoreMednafen-Dynamic",
            type: .dynamic,
            targets: ["MednafenGameCore"]),
        .library(
            name: "PVCoreMednafen-Static",
            type: .static,
            targets: ["MednafenGameCore"])
    ],
    dependencies: [
        .package(path: "../../PVAudio"),
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVSettings"),
        .package(path: "../../PVSupport"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        // MARK: --------- Core ------------ //
        .target(
            name: "MednafenGameCore",
            dependencies: [
                "MednafenGameCoreBridge",
                "MednafenGameCoreC",
                "MednafenGameCoreOptions",
                "PVAudio",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVEmulatorCore",
                "PVLogging",
                "PVPlists",
                "PVSettings",
                "PVSupport",
                "mednafen"
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .headerSearchPath("../mednafen/mednafen/include_mednafen"),
                .headerSearchPath("../mednafen/mednafen/include")
            ] + CSETTINGS,
            swiftSettings: [.interoperabilityMode(.Cxx)],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        // MARK: --------- Bridge ------------ //
        .target(
            name: "MednafenGameCoreBridge",
            dependencies: [
                "MednafenGameCoreC",
                "MednafenGameCoreOptions",
                "PVAudio",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVEmulatorCore",
                "PVLogging",
                "PVPlists",
                "PVSettings",
                "PVSupport",
                "mednafen"
            ],
            cSettings: [
                .unsafeFlags([
                    "-fcxx-exceptions",
                    "-fcxx-modules"
                ]),
                .headerSearchPath("../mednafen/mednafen/include_mednafen"),
                .headerSearchPath("../mednafen/mednafen/include"),
            ] + CSETTINGS
        ),
        // MARK: --------- Options ------------ //
        .target(
            name: "MednafenGameCoreOptions",
            dependencies: [
                "MednafenGameCoreC",
                "PVAudio",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVEmulatorCore",
                "PVLogging",
                "PVPlists",
                "PVSettings",
                "PVSupport",
                "mednafen"
            ]
        ),
        // MARK: --------- MednafenGameCoreC ------------ //
        .target(
            name: "MednafenGameCoreC",
            dependencies: [
                "mednafen",
            ],
            cSettings: [
                .headerSearchPath("./include"),
                .headerSearchPath("./include/MednafenGameCoreC"),
                .headerSearchPath("../mednafen/mednafen/include_mednafen"),
                .headerSearchPath("../mednafen/mednafen/include"),
            ] + CSETTINGS
        ),
        // MARK: --------- Mednafen ------------ //
        .target(
            name: "mednafen",
            dependencies: [
                /// Cores
                "apple2",
                "gb",
                "gba",
                "lynx",
                "neogeopocket",
                "megadrive",
                "nes",
                "pce",
                "pcefast",
                "pcfx",
                "psx",
                "saturn",
                "segamastersystem",
                "snes",
                "snes_faust",
                "virtualboy",
                "wonderswan",
                /// Hardware
                "compress",
                "cdrom",
                "hwaudio",
                "hwcpu",
                "hwmisc",
                "hwvideo",
                "mpcdec",
                "quicklz",
                "sound",
                "tremor",
                "trio",
                "video"
            ],
            path: "Sources/mednafen/",
            sources: Sources.Mednafen,
            cSettings: MEDNAFEN_C_SETTINGS,
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("iconv"),
            ]
        ),
        // MARK: --------- AppleII ------------ //
        .target(
            name: "apple2",
            path: "Sources/mednafen/",
            sources:Sources.Apple2.map { "mednafen/src/apple2/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- PSX ------------ //
        .target(
            name: "psx",
            path: "Sources/mednafen/",
            sources: Sources.PSX.map { "mednafen/src/psx/\($0)" },
            resources: [.copy("mednafen/src/psx/notes/")],
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- NES ------------ //
        .target(
            name: "nes",
            path: "Sources/mednafen/",
            sources: Sources.NES.map { "mednafen/src/nes/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- GameBoy ------------ //
        .target(
            name: "gb",
            path: "Sources/mednafen/",
            sources: Sources.GB.map { "mednafen/src/gb/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- GameBoy Advanced ------------ //
        .target(
            name: "gba",
            path: "Sources/mednafen/",
            sources: Sources.GBA.map { "mednafen/src/gba/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- Lynx ------------ //
        .target(
            name: "lynx",
            path: "Sources/mednafen/",
            sources: Sources.Lynx.map { "mednafen/src/lynx/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- NeoGeo Pocket ------------ //
        .target(
            name: "neogeopocket",
            path: "Sources/mednafen/",
            sources: Sources.NGP.map { "mednafen/src/ngp/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS +
            [.unsafeFlags(["-fno-strict-aliasing"])]
            // Neo Geo Pocket emulation code is now compiled with
            // -fno-strict-aliasing to work around issues in the TLCS-900h code.
        ),
        // MARK: --------- PCE ------------ //
        .target(
            name: "pce",
            path: "Sources/mednafen/",
            sources: Sources.PCE.map { "mednafen/src/pce/\($0)" },
            resources: [.copy("mednafen/src/pce/notes/")],
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- PCE Fast ------------ //
        .target(
            name: "pcefast",
            path: "Sources/mednafen/",
            sources: Sources.PCE_Fast.map { "mednafen/src/pce_fast/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- Sege Master System ------------ //
        .target(
            name: "segamastersystem",
            path: "Sources/mednafen/",
            sources: Sources.SMS.map { "mednafen/src/sms/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- PCFX ------------ //
        .target(
            name: "pcfx",
            path: "Sources/mednafen/",
            sources: Sources.PCFX.map { "mednafen/src/pcfx/\($0)" },
            resources: [.copy("mednafen/src/pcfx/notes/")],
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- MegaDrive ------------ //
        .target(
            name: "megadrive",
            path: "Sources/mednafen/",
            sources: Sources.MegaDrive.map { "mednafen/src/md/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- SNES ------------ //
        .target(
            name: "snes",
            path: "Sources/mednafen/",
            sources: Sources.SNES.map{ "mednafen/src/snes/\($0)"},
            cSettings: [
                .headerSearchPath("./mednafen/include_mednafen"),
                .headerSearchPath("./mednafen/include"),
                .headerSearchPath("./mednafen/src/snes/src"),
                .headerSearchPath("./mednafen/src/snes/src/lib/"),
                .headerSearchPath("./mednafen/src/snes/src/chip/st010/")
            ] + CSETTINGS
        ),
        // MARK: --------- SNES Faust ------------ //
        .target(
            name: "snes_faust",
            path: "Sources/mednafen/",
            sources: Sources.SNES_Faust.map{"mednafen/src/snes_faust/\($0)"},
            resources: [.copy("mednafen/src/snes_faust/notes/")],
            cSettings: [
                .headerSearchPath("./mednafen/include_mednafen"),
                .headerSearchPath("./mednafen/include"),
                .headerSearchPath("./mednafen/src/snes_faust/")
            ] + CSETTINGS
        ),
        // MARK: --------- Saturn ------------ //
        .target(
            name: "saturn",
            path: "Sources/mednafen/",
            sources: Sources.Saturn.map { "mednafen/src/ss/\($0)" },
            resources: [.copy("mednafen/src/ss/notes/")],
            cSettings: [
                .headerSearchPath("./mednafen/include_mednafen"),
                .headerSearchPath("./mednafen/include"),
                .headerSearchPath("./mednafen/src/ss")
            ] + CSETTINGS
        ),
        // MARK: --------- VirtualBoy ------------ //
        .target(
            name: "virtualboy",
            path: "Sources/mednafen/",
            sources: Sources.VirtualBoy.map { "mednafen/src/vb/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- WonderSwan ------------ //
        .target(
            name: "wonderswan",
            path: "Sources/mednafen/",
            sources: Sources.WonderSwan.map { "mednafen/src/wswan/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- HW Audio ------------ //
        .target(
            name: "hwaudio",
            path: "Sources/mednafen/",
            sources: Sources.HW.Audio.map { "mednafen/src/hw_sound/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- HW Video ------------ //
        .target(
            name: "hwvideo",
            path: "Sources/mednafen/",
            sources: Sources.HW.Video.map { "mednafen/src/hw_video/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- HW CPU ------------ //
        .target(
            name: "hwcpu",
            dependencies: ["hwcpu-m68k"],
            path: "Sources/mednafen/",
            sources: Sources.HW.CPU.map { "mednafen/src/hw_cpu/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- HW CPU m68k ------------ //
        .target(
            name: "hwcpu-m68k",
            path: "Sources/mednafen/",
            sources: Sources.HW.CPU_m68K.map { "mednafen/src/hw_cpu/m68k/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- HW Misc ------------ //
        .target(
            name: "hwmisc",
            path: "Sources/mednafen/",
            sources: Sources.HW.Misc.map { "mednafen/src/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- MPCDEC ------------ //
        .target(
            name: "mpcdec",
            path: "Sources/mednafen/",
            sources: Sources.MPCDEC.map { "mednafen/src/mpcdec/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- QuickLZ ------------ //
        .target(
            name: "quicklz",
            path: "Sources/mednafen/",
            sources: Sources.QuickLZ.map { "mednafen/src/quicklz/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS +
            [.unsafeFlags(["-fno-strict-aliasing"])]
            // compile QuickLZ with -fno-strict-aliasing to avoid potential future
            // trouble, since it does violate strict aliasing in at least a few places.
        ),
        // MARK: --------- Compress ------------ //
        .target(
            name: "compress",
            path: "Sources/mednafen/",
            sources: Sources.Compress.map { "mednafen/src/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- CD-ROM ------------ //
        .target(
            name: "cdrom",
            path: "Sources/mednafen/",
            sources: Sources.CDROM.map { "mednafen/src/cdrom/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- Sound ------------ //
        .target(
            name: "sound",
            path: "Sources/mednafen/",
            sources: Sources.Sound.map { "mednafen/src/sound/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- SASPlay ------------ //
        .target(
            name: "sasplay",
            path: "Sources/mednafen/",
            sources: Sources.SASPlay.map { "mednafen/src/sasplay/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
//        // MARK: --------- Sexy AL ------------ //
//        .target(
//            name: "sexyal",
//            path: "Sources/mednafen/mednafen/",
//            sources: [
//                "drivers/dummy.cpp",
//                "drivers/sdl.cpp",
//                "convert.cpp",
//                "sexyal.cpp"
//            ].map { "src/sexyal/\($0)" },
//            publicHeadersPath: "src/sexyal/",
//            cSettings: [
//                .headerSearchPath("./include_mednafen"),
//                .headerSearchPath("./include"),
//                .headerSearchPath("./")
//            ] + CSETTINGS
//        ),
        // MARK: --------- Tremor ------------ //
        .target(
            name: "tremor",
            path: "Sources/mednafen/",
            sources: Sources.Tremor.map { "mednafen/src/tremor/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- Trio ------------ //
        .target(
            name: "trio",
            path: "Sources/mednafen/",
            sources: Sources.Trio.map { "mednafen/src/trio/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- Video ------------ //
        .target(
            name: "video",
            path: "Sources/mednafen/",
            sources: Sources.Video.map { "mednafen/src/video/\($0)" },
            cSettings: MEDNAFEN_C_SETTINGS
        ),
        // MARK: --------- Tests ------------ //
        // MARK: --------- ====  ------------ //

        // MARK: --------- MednafenGameCore Tests ------------ //
        .testTarget(
            name: "MednafenGameCoreTests",
            dependencies: ["MednafenGameCore"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        // MARK: --------- MednafenGameCore C Tests ------------ //
//        .testTarget(
//            name: "MednafenGameCoreCTests",
//            dependencies: ["MednafenGameCoreC"],
//            swiftSettings: [.interoperabilityMode(.Cxx)]
//        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx11
)

enum Sources { }
extension Sources {
    static let Apple2: [String] = [
        "apple2.cpp",
        "disk2.cpp",
        "gameio.cpp",
        "hdd.cpp",
        "kbio.cpp",
        "sound.cpp",
        "video.cpp"
    ]
    static let CDROM: [String] = [
        "CDAFReader.cpp",
        "CDAFReader_MPC.cpp",
        "CDAFReader_PCM.cpp",
        "CDAFReader_Vorbis.cpp",
        "CDAccess.cpp",
        "CDAccess_CCD.cpp",
        "CDAccess_Image.cpp",
        "CDUtility.cpp",
        "crc32.cpp",
        "galois.cpp",
        "l-ec.cpp",
        "lec.cpp",
        "recover-raw.cpp",
        "scsicd.cpp"
    ]
    static let Compress: [String] = [
        "compress/ArchiveReader.cpp",
        "compress/ZIPReader.cpp",
        "compress/GZFileStream.cpp",
        "compress/DecompressFilter.cpp",
        "compress/ZstdDecompressFilter.cpp",
        "compress/ZLInflateFilter.cpp"
    ]
    static let GB: [String] = [
        "gb.cpp",
        "gbGlobals.cpp",
        "gfx.cpp",
        "memory.cpp",
        "sound.cpp",
        "z80.cpp"
    ]
    static let GBA: [String] = [
        "GBA.cpp",
        "GBAinline.cpp",
        "Gfx.cpp",
        "Globals.cpp",
        "Mode0.cpp",
        "Mode1.cpp",
        "Mode2.cpp",
        "Mode3.cpp",
        "Mode4.cpp",
        "Mode5.cpp",
        "RTC.cpp",
        "Sound.cpp",
        "arm.cpp",
        "bios.cpp",
        "eeprom.cpp",
        "flash.cpp",
        "sram.cpp",
        "thumb.cpp"
    ]
    static let Lynx: [String] = [
        "c65c02.cpp",
        "cart.cpp",
        "memmap.cpp",
        "mikie.cpp",
        "ram.cpp",
        "rom.cpp",
        "susie.cpp",
        "system.cpp"
    ]
    static let PCE: [String] = [
        "input/gamepad.cpp",
        "input/mouse.cpp",
        "input/tsushinkb.cpp",
        "dis6280.cpp",
        "hes.cpp",
        "huc.cpp",
        "huc6280.cpp",
        "input.cpp",
        "mcgenjin.cpp",
        "pce.cpp",
        "pcecd.cpp",
        "tsushin.cpp",
        "vce.cpp"
    ]
    static let PCE_Fast: [String] = [
        "hes.cpp",
        "huc.cpp",
        "huc6280.cpp",
        "input.cpp",
        "pce.cpp",
        "pcecd.cpp",
        "pcecd_drive.cpp",
        "psg.cpp",
        "vdc.cpp"
    ]
    static let Mednafen: [String] = [
        "time/Time_POSIX.cpp", // This was in the main framework target prior
        "ExtMemStream.cpp",
        "FileStream.cpp",
        "IPSPatcher.cpp",
        "MTStreamReader.cpp",
        "MemoryStream.cpp",
        "NativeVFS.cpp",
        "PSFLoader.cpp",
        "SSFLoader.cpp",
        "SNSFLoader.cpp",
        "SPCReader.cpp",
        "Stream.cpp",
        "VirtualFS.cpp",
        "cdplay/cdplay.cpp",
        "cdrom/CDInterface.cpp",
        "cdrom/CDInterface_MT.cpp",
        "cdrom/CDInterface_ST.cpp",
        "cheat_formats/gb.cpp",
        "cheat_formats/psx.cpp",
        "cheat_formats/snes.cpp",
        "cputest/cputest.c",
        "debug.cpp",
        "demo/demo.cpp",
        "endian.cpp",
        "error.cpp",
        "file.cpp",
        "general.cpp",
        "git.cpp",
        "hash/crc.cpp",
        "hash/md5.cpp",
        "hash/sha1.cpp",
        "hash/sha256.cpp",
        "mednafen.cpp",
        "memory.cpp",
        "mempatcher.cpp",
        "minilzo/minilzo.c",
        "movie.cpp",
        "mthreading/MThreading_POSIX.cpp",
        "net/Net.cpp",
        "net/Net_POSIX.cpp",
        "netplay.cpp",
        "player.cpp",
        "qtrecord.cpp",
        "resampler/resample.c",
        "settings.cpp",
        "state.cpp",
        "state_rewind.cpp",
        "string/escape.cpp",
        "string/string.cpp",
        "tests.cpp",
        "zstd/common/entropy_common.c",
        "zstd/common/error_private.c",
        "zstd/common/fse_decompress.c",
        "zstd/common/xxhash.c",
        "zstd/common/zstd_common.c",
        "zstd/decompress/huf_decompress.c",
        "zstd/decompress/zstd_ddict.c",
        "zstd/decompress/zstd_decompress_block.c",
        "zstd/decompress/zstd_decompress.c"
    ].map { "mednafen/src/\($0)" }
    static let MegaDrive: [String] = [
        "cart/cart.cpp",
        "cart/map_eeprom.cpp",
        "cart/map_ff.cpp",
        "cart/map_realtec.cpp",
        "cart/map_rmx3.cpp",
        "cart/map_rom.cpp",
        "cart/map_sbb.cpp",
        "cart/map_sram.cpp",
        "cart/map_ssf2.cpp",
        "cart/map_svp.cpp",
        "cart/map_yase.cpp",
        "cd/cd.cpp",
        "cd/cdc_cdd.cpp",
        "cd/interrupt.cpp",
        "cd/pcm.cpp",
        "cd/timer.cpp",
        "genesis.cpp",
        "genio.cpp",
        "header.cpp",
        "input/4way.cpp",
        "input/gamepad.cpp",
        "input/megamouse.cpp",
        "input/multitap.cpp",
        "mem68k.cpp",
        "membnk.cpp",
        "memvdp.cpp",
        "memz80.cpp",
        "sound.cpp",
        "system.cpp",
        "vdp.cpp"
    ]
    static let MPCDEC: [String] = [
        "crc32.c",
        "huffman.c",
        "mpc_bits_reader.c",
        "mpc_decoder.c",
        "mpc_demux.c",
        "requant.c",
        "streaminfo.c",
        "synth_filter.c"
    ]
    static let NES: [String] = [
        "boards/107.cpp",
        "boards/112.cpp",
        "boards/113.cpp",
        "boards/114.cpp",
        "boards/117.cpp",
        "boards/140.cpp",
        "boards/15.cpp",
        "boards/151.cpp",
        "boards/152.cpp",
        "boards/156.cpp",
        "boards/16.cpp",
        "boards/163.cpp",
        "boards/18.cpp",
        "boards/180.cpp",
        "boards/182.cpp",
        "boards/184.cpp",
        "boards/185.cpp",
        "boards/187.cpp",
        "boards/189.cpp",
        "boards/190.cpp",
        "boards/193.cpp",
        "boards/208.cpp",
        "boards/21.cpp",
        "boards/22.cpp",
        "boards/222.cpp",
        "boards/228.cpp",
        "boards/23.cpp",
        "boards/232.cpp",
        "boards/234.cpp",
        "boards/240.cpp",
        "boards/241.cpp",
        "boards/242.cpp",
        "boards/244.cpp",
        "boards/246.cpp",
        "boards/248.cpp",
        "boards/25.cpp",
        "boards/30.cpp",
        "boards/32.cpp",
        "boards/33.cpp",
        "boards/34.cpp",
        "boards/38.cpp",
        "boards/40.cpp",
        "boards/41.cpp",
        "boards/42.cpp",
        "boards/46.cpp",
        "boards/51.cpp",
        "boards/65.cpp",
        "boards/67.cpp",
        "boards/68.cpp",
        "boards/70.cpp",
        "boards/72.cpp",
        "boards/73.cpp",
        "boards/75.cpp",
        "boards/76.cpp",
        "boards/77.cpp",
        "boards/78.cpp",
        "boards/8.cpp",
        "boards/80.cpp",
        "boards/82.cpp",
        "boards/8237.cpp",
        "boards/86.cpp",
        "boards/87.cpp",
        "boards/88.cpp",
        "boards/89.cpp",
        "boards/90.cpp",
        "boards/92.cpp",
        "boards/93.cpp",
        "boards/94.cpp",
        "boards/95.cpp",
        "boards/96.cpp",
        "boards/97.cpp",
        "boards/99.cpp",
        "boards/codemasters.cpp",
        "boards/colordreams.cpp",
        "boards/deirom.cpp",
        "boards/emu2413.cpp",
        "boards/ffe.cpp",
        "boards/fme7.cpp",
        "boards/h2288.cpp",
        "boards/malee.cpp",
        "boards/maxicart.cpp",
        "boards/mmc1.cpp",
        "boards/mmc2and4.cpp",
        "boards/mmc3.cpp",
        "boards/mmc5.cpp",
        "boards/n106.cpp",
        "boards/nina06.cpp",
        "boards/novel.cpp",
        "boards/sachen.cpp",
        "boards/simple.cpp",
        "boards/super24.cpp",
        "boards/supervision.cpp",
        "boards/tengen.cpp",
        "boards/vrc6.cpp",
        "boards/vrc7.cpp",
        "cart.cpp",
        "dis6502.cpp",
        "fds-sound.cpp",
        "fds.cpp",
        "ines.cpp",
        "input.cpp",
        "input/arkanoid.cpp",
        "input/bbattler2.cpp",
        "input/cursor.cpp",
        "input/fkb.cpp",
        "input/ftrainer.cpp",
        "input/hypershot.cpp",
        "input/mahjong.cpp",
        "input/oekakids.cpp",
        "input/partytap.cpp",
        "input/powerpad.cpp",
        "input/shadow.cpp",
        "input/suborkb.cpp",
        "input/toprider.cpp",
        "input/zapper.cpp",
        "nes.cpp",
        "nsf.cpp",
        "nsfe.cpp",
        "ntsc/nes_ntsc.cpp",
        "ppu/palette.cpp",
        "ppu/ppu.cpp",
        "sound.cpp",
        "unif.cpp",
        "vsuni.cpp",
        "x6502.cpp"
    ]
    static let NGP: [String] = [
        "T6W28_Apu.cpp",
        "TLCS-900h/TLCS900h_disassemble.cpp",
        "TLCS-900h/TLCS900h_disassemble_dst.cpp",
        "TLCS-900h/TLCS900h_disassemble_extra.cpp",
        "TLCS-900h/TLCS900h_disassemble_reg.cpp",
        "TLCS-900h/TLCS900h_disassemble_src.cpp",
        "TLCS-900h/TLCS900h_interpret.cpp",
        "TLCS-900h/TLCS900h_interpret_dst.cpp",
        "TLCS-900h/TLCS900h_interpret_reg.cpp",
        "TLCS-900h/TLCS900h_interpret_single.cpp",
        "TLCS-900h/TLCS900h_interpret_src.cpp",
        "TLCS-900h/TLCS900h_registers.cpp",
        "Z80_interface.cpp",
        "bios.cpp",
        "biosHLE.cpp",
        "dma.cpp",
        "flash.cpp",
        "gfx.cpp",
        "gfx_scanline_colour.cpp",
        "gfx_scanline_mono.cpp",
        "interrupt.cpp",
        "mem.cpp",
        "neopop.cpp",
        "rom.cpp",
        "rtc.cpp",
        "sound.cpp"
    ]
    static let PCFX: [String] = [
        "fxscsi.cpp",
        "huc6273.cpp",
        "idct.cpp",
        "input.cpp",
        "input/gamepad.cpp",
        "input/mouse.cpp",
        "interrupt.cpp",
        "king.cpp",
        "pcfx.cpp",
        "rainbow.cpp",
        "soundbox.cpp",
        "timer.cpp"
    ]
    static let PSX: [String] = [
        "cdc.cpp",
        "cpu.cpp",
        "dis.cpp",
        "dma.cpp",
        "frontio.cpp",
        "gpu.cpp",
        "gpu_line.cpp",
        "gpu_polygon.cpp",
        "gpu_sprite.cpp",
        "gte.cpp",
        "input/dualanalog.cpp",
        "input/dualshock.cpp",
        "input/gamepad.cpp",
        "input/guncon.cpp",
        "input/justifier.cpp",
        "input/memcard.cpp",
        "input/mouse.cpp",
        "input/multitap.cpp",
        "input/negcon.cpp",
        "irq.cpp",
        "mdec.cpp",
        "psx.cpp",
        "sio.cpp",
        "spu.cpp",
        "timer.cpp"
    ]
    static let QuickLZ: [String] = ["quicklz.c"]
    static let SASPlay: [String] = ["sasplay.cpp"]
    static let Saturn: [String] = [
        "ak93c45.cpp",
        "cart.cpp",
        "cart/ar4mp.cpp",
        "cart/backup.cpp",
        "cart/bootrom.cpp",
        "cart/cs1ram.cpp",
        "cart/extram.cpp",
        "cart/rom.cpp",
        "cart/stv.cpp",
        "cdb.cpp",
        "db.cpp",
        "input/3dpad.cpp",
        "input/gamepad.cpp",
        "input/gun.cpp",
        "input/jpkeyboard.cpp",
        "input/keyboard.cpp",
        "input/mission.cpp",
        "input/mouse.cpp",
        "input/multitap.cpp",
        "input/wheel.cpp",
        "notes/gen_dsp.cpp",
        "scu_dsp_gen.cpp",
        "scu_dsp_jmp.cpp",
        "scu_dsp_misc.cpp",
        "scu_dsp_mvi.cpp",
        "smpc.cpp",
        "sound.cpp",
        "ss.cpp",
        "ssf.cpp",
        "stvio.cpp",
        "vdp1.cpp",
        "vdp1_line.cpp",
        "vdp1_poly.cpp",
        "vdp1_sprite.cpp",
        "vdp2.cpp",
        "vdp2_render.cpp"
    ]
    static let SMS: [String] = [
        "cart.cpp",
        "memz80.cpp",
        "pio.cpp",
        "render.cpp",
        "romdb.cpp",
        "sms.cpp",
        "sound.cpp",
        "system.cpp",
        "tms.cpp",
        "vdp.cpp"
    ]
    static let SNES_Faust: [String] = [
        "apu.cpp",
        "cart.cpp",
        "cart/cx4.cpp",
        "cart/dsp1.cpp",
        "cart/dsp2.cpp",
        "cart/sa1.cpp",
        "cart/sa1cpu.cpp",
        "cart/sdd1.cpp",
        "cart/superfx.cpp",
        "cpu.cpp",
//        "debug.cpp",
        "dis65816.cpp",
        "input.cpp",
        "input/multitap.cpp",
        "input/mouse.cpp",
        "input/gamepad.cpp",
        "msu1.cpp",
        "ppu.cpp",
        "ppu_mt.cpp",
        "ppu_mtrender.cpp",
        "ppu_st.cpp",
        "snes.cpp"
    ]
    static let SNES: [String] = [
        "interface.cpp",
        "src/cartridge/cartridge.cpp",
        "src/cartridge/gameboyheader.cpp",
        "src/cartridge/header.cpp",
        "src/cartridge/serialization.cpp",
        "src/cheat/cheat.cpp",
        "src/chip/bsx/bsx.cpp",
        "src/chip/bsx/bsx_base.cpp",
        "src/chip/bsx/bsx_cart.cpp",
        "src/chip/bsx/bsx_flash.cpp",
        "src/chip/cx4/cx4.cpp",
        "src/chip/cx4/data.cpp",
        "src/chip/cx4/functions.cpp",
        "src/chip/cx4/oam.cpp",
        "src/chip/cx4/opcodes.cpp",
        "src/chip/cx4/serialization.cpp",
        "src/chip/dsp1/dsp1.cpp",
        "src/chip/dsp1/dsp1emu.cpp",
        "src/chip/dsp1/serialization.cpp",
        "src/chip/dsp2/dsp2.cpp",
        "src/chip/dsp2/opcodes.cpp",
        "src/chip/dsp2/serialization.cpp",
        "src/chip/dsp3/dsp3.cpp",
        "src/chip/dsp3/dsp3emu.c",
        "src/chip/dsp4/dsp4.cpp",
        "src/chip/dsp4/dsp4emu.c",
        "src/chip/obc1/obc1.cpp",
        "src/chip/obc1/serialization.cpp",
        "src/chip/sa1/bus/bus.cpp",
        "src/chip/sa1/dma/dma.cpp",
        "src/chip/sa1/memory/memory.cpp",
        "src/chip/sa1/mmio/mmio.cpp",
        "src/chip/sa1/sa1.cpp",
        "src/chip/sa1/serialization.cpp",
        "src/chip/sdd1/sdd1.cpp",
        "src/chip/sdd1/sdd1emu.cpp",
        "src/chip/sdd1/serialization.cpp",
        "src/chip/spc7110/decomp.cpp",
        "src/chip/spc7110/serialization.cpp",
        "src/chip/spc7110/spc7110.cpp",
        "src/chip/srtc/serialization.cpp",
        "src/chip/srtc/srtc.cpp",
        "src/chip/st010/serialization.cpp",
        "src/chip/st010/st010.cpp",
        "src/chip/st010/st010_op.cpp",
        "src/chip/superfx/bus/bus.cpp",
        "src/chip/superfx/core/core.cpp",
        "src/chip/superfx/core/opcode_table.cpp",
        "src/chip/superfx/core/opcodes.cpp",
        "src/chip/superfx/disasm/disasm.cpp",
        "src/chip/superfx/memory/memory.cpp",
        "src/chip/superfx/mmio/mmio.cpp",
        "src/chip/superfx/serialization.cpp",
        "src/chip/superfx/superfx.cpp",
        "src/chip/superfx/timing/timing.cpp",
        "src/cpu/core/algorithms.cpp",
        "src/cpu/core/core.cpp",
        "src/cpu/core/opcode_misc.cpp",
        "src/cpu/core/opcode_pc.cpp",
        "src/cpu/core/opcode_read.cpp",
        "src/cpu/core/opcode_rmw.cpp",
        "src/cpu/core/opcode_write.cpp",
        "src/cpu/core/serialization.cpp",
        "src/cpu/core/table.cpp",
        "src/cpu/cpu.cpp",
        "src/cpu/scpu/dma/dma.cpp",
        "src/cpu/scpu/memory/memory.cpp",
        "src/cpu/scpu/mmio/mmio.cpp",
        "src/cpu/scpu/scpu.cpp",
        "src/cpu/scpu/serialization.cpp",
        "src/cpu/scpu/timing/event.cpp",
        "src/cpu/scpu/timing/irq.cpp",
        "src/cpu/scpu/timing/joypad.cpp",
        "src/cpu/scpu/timing/timing.cpp",
        "src/lib/libco/libco.c",
        "src/memory/memory.cpp",
        "src/memory/smemory/generic.cpp",
        "src/memory/smemory/serialization.cpp",
        "src/memory/smemory/smemory.cpp",
        "src/memory/smemory/system.cpp",
        "src/ppu/memory/memory.cpp",
        "src/ppu/mmio/mmio.cpp",
        "src/ppu/ppu.cpp",
        "src/ppu/render/addsub.cpp",
        "src/ppu/render/bg.cpp",
        "src/ppu/render/cache.cpp",
        "src/ppu/render/line.cpp",
        "src/ppu/render/mode7.cpp",
        "src/ppu/render/oam.cpp",
        "src/ppu/render/render.cpp",
        "src/ppu/render/windows.cpp",
        "src/ppu/serialization.cpp",
        "src/sdsp/brr.cpp",
        "src/sdsp/counter.cpp",
        "src/sdsp/echo.cpp",
        "src/sdsp/envelope.cpp",
        "src/sdsp/gaussian.cpp",
        "src/sdsp/misc.cpp",
        "src/sdsp/sdsp.cpp",
        "src/sdsp/serialization.cpp",
        "src/sdsp/voice.cpp",
        "src/smp/core/algorithms.cpp",
        "src/smp/core/opcode_misc.cpp",
        "src/smp/core/opcode_mov.cpp",
        "src/smp/core/opcode_pc.cpp",
        "src/smp/core/opcode_read.cpp",
        "src/smp/core/opcode_rmw.cpp",
        "src/smp/core/serialization.cpp",
        "src/smp/core/table.cpp",
        "src/smp/smp.cpp",
        "src/system/audio/audio.cpp",
        "src/system/config/config.cpp",
        "src/system/input/input.cpp",
        "src/system/scheduler/scheduler.cpp",
        "src/system/serialization.cpp",
        "src/system/system.cpp",
        "src/system/video/video.cpp"
    ]
    static let Sound: [String] = [
        "Blip_Buffer.cpp",
        "DSPUtility.cpp",
        "Fir_Resampler.cpp",
        "OwlResampler.cpp",
        "Stereo_Buffer.cpp",
        "SwiftResampler.cpp",
        "WAVRecord.cpp",
        "okiadpcm.cpp"
    ]
    static let Tremor: [String] = [
        "bitwise.c",
        "block.c",
        "codebook.c",
        "floor0.c",
        "floor1.c",
        "framing.c",
        "info.c",
        "mapping0.c",
        "mdct.c",
        "registry.c",
        "res012.c",
        "sharedbook.c",
        "synthesis.c",
        "vorbisfile.c",
        "window.c"
    ]
    static let Trio: [String] = [
        "trio.c",
        "trionan.c",
        "triostr.c"
    ]
    static let Video: [String] =  [
        "convert.cpp",
        "surface.cpp",
        "tblur.cpp",
        "text.cpp",
        "Deinterlacer.cpp",
        "Deinterlacer_Simple.cpp",
        "Deinterlacer_Blend.cpp",
        "resize.cpp",
        "video.cpp",
        "primitives.cpp",
        "png.cpp",
        "font-data.cpp",
        "font-data-18x18.cpp", // Must manually rename to .cpp
        "font-data-12x13.cpp", // Must manually rename to .cpp
    ]
    static let VirtualBoy: [String] = [
        "input.cpp",
//        "debug.cpp",
        "timer.cpp",
        "vb.cpp",
        "vip.cpp",
        "vsu.cpp"
    ]
    static let WonderSwan: [String] = [
        "comm.cpp",
//        "debug.cpp",
        "eeprom.cpp",
        "gfx.cpp",
        "interrupt.cpp",
        "memory.cpp",
        "rtc.cpp",
        "sound.cpp",
        "tcache.cpp",
        "v30mz.cpp",
        "wswan_main.cpp"
    ]
}

extension Sources {
    enum HW {
        static let Audio: [String] = [
            "gb_apu/Gb_Apu.cpp",
            "gb_apu/Gb_Apu_State.cpp",
            "gb_apu/Gb_Oscs.cpp",
            "pce_psg/pce_psg.cpp",
            "sms_apu/Sms_Apu.cpp",
            "ym2413/emu2413.cpp",
            "ym2612/Ym2612_Emu.cpp"
        ]
        static let CPU: [String] = [
            "v810/v810_cpu.cpp",
            "v810/v810_fp_ops.cpp",
            "z80-fuse/z80.cpp",
            "z80-fuse/z80_ops.cpp"
        ]
        static let CPU_m68K: [String] = [
            "m68k.cpp"
        ]
        static let Misc: [String] = [
            "testsexp.cpp",
            "hw_misc/arcade_card/arcade_card.cpp"
        ]
        static let Video: [String] = [
            "huc6270/vdc.cpp",
        ]
    }
}
