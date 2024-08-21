// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let GCC_PREPROCESSOR_DEFINITIONS: [CSetting] =
    "HAVE_LROUND HAVE_MKDIR HAVE_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP HAVE_STDINT_H HAVE_STDLIB_H HAVE_SYS_PARAM_H HAVE_UNISTD_H LSB_FIRST MPC_FIXED_POINT PSS_STYLE=1 SIZEOF_CHAR=1 SIZEOF_DOUBLE=8 SIZEOF_INT=4 SIZEOF_LONG=8 SIZEOF_LONG_LONG=8 SIZEOF_OFF_T=8 SIZEOF_PTRDIFF_T=8 SIZEOF_SHORT=2 SIZEOF_SIZE_T=8 SIZEOF_VOID_P=8 STDC_HEADERS WANT_FANCY_SCALERS=1 WANT_GB_EMU WANT_GBA_EMU WANT_LYNX_EMU WANT_NES_EMU WANT_NGP_EMU WANT_PCE_EMU WANT_PCE_FAST_EMU WANT_PCFX_EMU WANT_PSX_EMU WANT_SNES_EMU WANT_SNES_FAUST_EMU WANT_SS_EMU WANT_STEREO_SOUND WANT_VB_EMU WANT_WSWAN_EMU __LIBRETRO__ __STDC_LIMIT_MACROS=1 ICONV_CONST"
    .split(separator: " ")
    .map {
        let split = $0.split(separator: "=")
        if split.count == 2 {
            return CSetting.define(String(split[0]), to: String(split[1]))
        } else {
            return CSetting.define(String($0))
        }
    }

// -funroll-loops -fPIC -Wall -Wno-sign-compare -Wno-unused-variable -Wno-unused-function -Wno-uninitialized -Wno-strict-aliasing -Wno-aggressive-loop-optimizations -fno-fast-math -fomit-frame-pointer -fsigned-char -Wshadow -Wempty-body -Wignored-qualifiers -Wvla -Wvariadic-macros -Wdisabled-optimization -fmodules -fcxx-modules -DMEDNAFEN_VERSION=\"1.27.1\" -DPACKAGE=\"mednafen\" -DICONV_CONST=
let OTHER_CFLAGS: [CSetting] = [
    .unsafeFlags(
        "-funroll-loops -fPIC -Wall -Wno-sign-compare -Wno-unused-variable -Wno-unused-function -Wno-uninitialized -Wno-strict-aliasing -Wno-aggressive-loop-optimizations -fno-fast-math -fomit-frame-pointer -fsigned-char -Wshadow -Wempty-body -Wignored-qualifiers -Wvla -Wvariadic-macros -Wdisabled-optimization -fmodules -fcxx-modules".split(separator: " ").map(String.init)
    )
]

let CSETTINGS: [CSetting] = [
    .define("MEDNAFEN_VERSION_NUMERIC", to: "0x00102701"),
    .define("MEDNAFEN_VERSION", to: "1.27.1"),
    .define("PACKAGE", to: "mednafen"),
    .define("INLINE", to: "inline"),
    
    .define("HAVE_CONFIG_H", to: "1"),

    .define("DEBUG", to: "1", .when(configuration: .debug)),
    .define("NDEBUG", to: "1", .when(configuration: .release)),
//    .headerSearchPath("./"),
//    .headerSearchPath("../"),
//    .headerSearchPath("../include"),
//    .headerSearchPath("../../include"),
] + GCC_PREPROCESSOR_DEFINITIONS + OTHER_CFLAGS

let package = Package(
    name: "MednafenGameCore",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MednafenGameCore",
            targets: ["MednafenGameCore", "MednafenGameCoreSwift", "MednafenGameCoreC"]),
        .library(
            name: "MednafenGameCore-Dynamic",
            type: .dynamic,
            targets: ["MednafenGameCore", "MednafenGameCoreSwift", "MednafenGameCoreC"]),
        .library(
            name: "MednafenGameCore-Static",
            type: .static,
            targets: ["MednafenGameCore", "MednafenGameCoreSwift", "MednafenGameCoreC"])
    ],
    dependencies: [
        .package(path: "../../PVAudio"),
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVSettings"),
        .package(path: "../../PVSupport"),
    ],
    targets: [
        
        // MARK: MednafenGameCore

        .target(
            name: "MednafenGameCore",
            dependencies: [
                "MednafenGameCoreC",
                "MednafenGameCoreSwift",
                "PVAudio",
                "PVCoreBridge",
                "PVEmulatorCore",
                "PVLogging",
                "PVPlists",
                "PVSettings",
                "PVSupport"
            ],
            path: "Sources/MednafenGameCore",
            cSettings: CSETTINGS
        ),
        
        // MARK: MednafenGameCoreSwift
        
            .target(
                name: "MednafenGameCoreSwift",
                dependencies: [
                    "MednafenGameCoreC",
                    "PVAudio",
                    "PVCoreBridge",
                    "PVEmulatorCore",
                    "PVLogging",
                    "PVPlists",
                    "PVSettings",
                    "PVSupport"
                ],
                path: "Sources/MednafenGameCoreSwift",
                cSettings: CSETTINGS,
                swiftSettings: [.interoperabilityMode(.Cxx)]
            ),
        
        // MARK: PVMednafenGameCoreC

            .target(
                name: "MednafenGameCoreC",
                dependencies: [
                    "saturn",
                    "psx",
                    "wonderswan",
                    "virtualboy",
                    "nes",
                    "mednafen"
                ],
                cSettings: CSETTINGS
            ),
      
        // MARK: psx

            .target(
                name: "psx",
                path: "Sources/mednafen/mednafen/src/psx",
                sources: [
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
                ],
                cSettings: CSETTINGS
            ),
        
        // MARK: wonderswan
        
            .target(
                name: "wonderswan",
                path: "Sources/mednafen/mednafen/src/wswan",
                sources: [
                    "comm.cpp",
                    "eeprom.cpp",
                    "gfx.cpp",
                    "interrupt.cpp",
                    "memory.cpp",
                    "rtc.cpp",
                    "sound.cpp",
                    "tcache.cpp",
                    "v30mz.cpp",
                    "wswan_main.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("../include"),
                ] + CSETTINGS
            ),
        
        // MARK: virtualboy

            .target(
                name: "virtualboy",
                path: "Sources/mednafen/mednafen/src/vb",
                sources: [
                    "input.cpp",
                    "timer.cpp",
                    "vb.cpp",
                    "vip.cpp",
                    "vsu.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),

        // MARK: nes
        
            .target(
                name: "nes",
                path: "Sources/mednafen/mednafen/src/nes",
                sources: [
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
                ],
                cSettings: CSETTINGS
            ),

        // MARK: gb
        
            .target(
                name: "gb",
                path: "Sources/mednafen/mednafen/src/gb",
                sources: [
                    "gb.cpp",
                    "gbGlobals.cpp",
                    "gfx.cpp",
                    "memory.cpp",
                    "sound.cpp",
                    "z80.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: gba

            .target(
                name: "gba",
                path: "Sources/mednafen/mednafen/src/gba",
                sources: [
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
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),

        // MARK: lynx
        
            .target(
                name: "lynx",
                path: "Sources/mednafen/mednafen/src/lynx",
                sources: [
                    "c65c02.cpp",
                    "cart.cpp",
                    "memmap.cpp",
                    "mikie.cpp",
                    "ram.cpp",
                    "rom.cpp",
                    "susie.cpp",
                    "system.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: neogeopocket

            .target(
                name: "neogeopocket",
                path: "Sources/mednafen/mednafen/src/ngp",
                sources: [
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
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: pce
        
            .target(
                name: "pce",
                path: "Sources/mednafen/mednafen/src/pce",
                sources: [
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
                ],
                resources: [
                    .copy("notes/")
                ],
                cSettings: CSETTINGS
            ),
        
        // MARK: pcefast

            .target(
                name: "pcefast",
                path: "Sources/mednafen/mednafen/src/pce_fast",
                sources: [
                    "hes.cpp",
                    "huc.cpp",
                    "huc6280.cpp",
                    "input.cpp",
                    "pce.cpp",
                    "pcecd.cpp",
                    "pcecd_drive.cpp",
                    "psg.cpp",
                    "vdc.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: segamastersystem

            .target(
                name: "segamastersystem",
                path: "Sources/mednafen/mednafen/src/sms",
                sources: [
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
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: pcfx

            .target(
                name: "pcfx",
                path: "Sources/mednafen/mednafen/src/pcfx",
                sources: [
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
                ],
                resources: [
                    .copy("notes/")
                ],
                cSettings: CSETTINGS
            ),
        
        // MARK: megadrive

            .target(
                name: "megadrive",
                path: "Sources/mednafen/mednafen/src/md",
                sources: [
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
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: hwaudio

            .target(
                name: "hwaudio",
                path: "Sources/mednafen/mednafen/src/hw_sound",
                sources: [
                    "gb_apu/Gb_Apu.cpp",
                    "gb_apu/Gb_Apu_State.cpp",
                    "gb_apu/Gb_Oscs.cpp",
                    "pce_psg/pce_psg.cpp",
                    "sms_apu/Sms_Apu.cpp",
                    "ym2413/emu2413.cpp",
                    "ym2612/Ym2612_Emu.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: hwvideo

            .target(
                name: "hwvideo",
                path: "Sources/mednafen/mednafen/src/hw_video",
                sources: [
                    "huc6270/vdc.cpp",
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: hwcpu

            .target(
                name: "hwcpu",
                path: "Sources/mednafen/mednafen/src/hw_cpu",
                sources: [
                    "v810/v810_cpu.cpp",
                    "v810/v810_fp_ops.cpp",
                    "z80-fuse/z80.cpp",
                    "z80-fuse/z80_ops.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: hwcpu-m68k

            .target(
                name: "hwcpu-m68k",
                path: "Sources/mednafen/mednafen/src/hw_cpu/m68k",
                sources: [
                    "m68k.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: hwmisc

            .target(
                name: "hwmisc",
                path: "Sources/mednafen/mednafen/src/",
                sources: [
                    "testsexp.cpp",
                    "hw_misc/arcade_card/arcade_card.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: cdrom
        
            .target(
                name: "cdrom",
                path: "Sources/mednafen/mednafen/src/cdrom",
                sources: [
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
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: sound

            .target(
                name: "sound",
                path: "Sources/mednafen/mednafen/src/sound",
                sources: [
                    "Blip_Buffer.cpp",
                    "DSPUtility.cpp",
                    "Fir_Resampler.cpp",
                    "OwlResampler.cpp",
                    "Stereo_Buffer.cpp",
                    "SwiftResampler.cpp",
                    "WAVRecord.cpp",
                    "okiadpcm.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: sexyal

//            .target(
//                name: "sexyal",
//                path: "Sources/mednafen/mednafen/src/sexyal",
//                sources: [
//                    "drivers/dummy.cpp",
//                    "drivers/sdl.cpp",
//                    "convert.cpp",
//                    "sexyal.cpp"
//                ],
//                publicHeadersPath: "."
//            ),
        
        // MARK: video

            .target(
                name: "video",
                path: "Sources/mednafen/mednafen/src/video",
                sources: [
                    "Deinterlacer.cpp",
                    "convert.cpp",
                    "font-data.cpp",
                    "png.cpp",
                    "primitives.cpp",
                    "resize.cpp",
                    "surface.cpp",
                    "tblur.cpp",
                    "text.cpp",
                    "video.cpp"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: mednafen

            .target(
                name: "mednafen",
                dependencies: [
                    "cdrom",
                    "hwaudio",
                    "hwcpu",
                    "hwcpu-m68k",
                    "hwmisc",
                    "hwvideo",
                    "pcefast",
                    "pcfx",
                    "segamastersystem",
                    "megadrive",
                    "snes",
                    "sound",
                    "tremor",
                    "trio",
                    "video"
                ],
                path: "Sources/mednafen/",
                sources: [
                    "time/Time_POSIX.cpp", // This was in the main framework target prior
                    
                    "ExtMemStream.cpp",
                    "FileStream.cpp",
                    "IPSPatcher.cpp",
                    "MTStreamReader.cpp",
                    "MemoryStream.cpp",
                    "NativeVFS.cpp",
                    "PSFLoader.cpp",
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
                    "compress/GZFileStream.cpp",
                    "compress/ZIPReader.cpp",
                    "compress/ZLInflateFilter.cpp",
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
                    "movie.cpp",
                    "mthreading/MThreading_POSIX.cpp",
                    "net/Net.cpp",
                    "net/Net_POSIX.cpp",
                    "netplay.cpp",
                    "player.cpp",
                    "resampler/resample.c",
                    "settings.cpp",
//                    "sound/DSPUtility.cpp",
//                    "sound/SwiftResampler.cpp",
                    "state.cpp",
                    "state_rewind.cpp",
                    "string/escape.cpp",
                    "string/string.cpp",
                    "video/Deinterlacer_Blend.cpp",
                    "video/Deinterlacer_Simple.cpp"
                ].map { "mednafen/src/\($0)" },
                publicHeadersPath: "./include/mednafen",
                cSettings: CSETTINGS
            ),
        
        // MARK: mpcdec

            .target(
                name: "mpcdec",
                path: "Sources/mednafen/mednafen/src/mpcdec",
                sources: [
                    "crc32.c",
                    "huffman.c",
                    "mpc_bits_reader.c",
                    "mpc_decoder.c",
                    "mpc_demux.c",
                    "requant.c",
                    "streaminfo.c",
                    "synth_filter.c"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: quicklz

            .target(
                name: "quicklz",
                path: "Sources/mednafen/mednafen/src/quicklz/",
                sources: [
                    "quicklz.c"
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: Tremor

            .target(
                name: "tremor",
                path: "Sources/mednafen/mednafen/src/tremor",
                sources: [
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
                ],
                publicHeadersPath: ".",
                cSettings: CSETTINGS
            ),
        
        // MARK: Trio

            .target(
                name: "trio",
                path: "Sources/mednafen/mednafen/src/trio",
                sources: [
                    "trio.c",
                    "trionan.c",
                    "triostr.c"
                ],
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("../")
                ] + CSETTINGS
            ),
        
        // MARK: SNES

            .target(
                name: "snes",
                path: "Sources/mednafen/mednafen/src/snes",
                sources:[
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
                    "src/lib/libco/arm.c",
                    "src/lib/libco/libco.c",
                    "src/lib/libco/sjlj.c",
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
                ],
                publicHeadersPath: "./",
                cSettings: CSETTINGS
            ),
        
        // MARK: SNES Faust

            .target(
                name: "snes_faust",
                path: "Sources/mednafen/mednafen/src/snes_faust",
                sources: [
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
                    "debug.cpp",
                    "dis65816.cpp",
                    "input.cpp",
                    "msu1.cpp",
                    "ppu.cpp",
                    "ppu_mt.cpp",
                    "ppu_mtrender.cpp",
                    "ppu_st.cpp",
                    "snes.cpp"
                ],
                publicHeadersPath: "./",
                cSettings: CSETTINGS
            ),
        
            // MARK: Saturn
        
            .target(
                name: "saturn",
                path: "Sources/mednafen/mednafen/src/ss",
                sources: [
                    "cart.cpp",
                    "cart/ar4mp.cpp",
                    "cart/backup.cpp",
                    "cart/cs1ram.cpp",
                    "cart/debug.cpp",
                    "cart/extram.cpp",
                    "cart/rom.cpp",
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
                    "vdp1.cpp",
                    "vdp1_line.cpp",
                    "vdp1_poly.cpp",
                    "vdp1_sprite.cpp",
                    "vdp2.cpp",
                    "vdp2_render.cpp"
                ],
                publicHeadersPath: "./",
                cSettings: CSETTINGS
            ),
        
        // MARK: - Tests
        
        // MARK: MednafenTests

        .testTarget(
            name: "MednafenGameCoreTests",
            dependencies: ["MednafenGameCore"]
        ),
    
        // MARK: PVMednafenGameCoreCTests

        .testTarget(
            name: "MednafenGameCoreCTests",
            dependencies: ["MednafenGameCoreC"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx14
    
)
