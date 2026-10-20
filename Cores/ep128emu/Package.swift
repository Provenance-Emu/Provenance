// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVEP128Emu",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PVEP128Emu", targets: ["PVEP128Emu"]),
        .library(name: "PVEP128Emu-Dynamic", type: .dynamic, targets: ["PVEP128Emu"])
    ],
    dependencies: [
        .package(path: "../../PVCoreBridgeRetro"),
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVPlists")
    ],
    targets: [
        .target(
            name: "PVEP128Emu",
            dependencies: [
                "PVEP128EmuBridge", "PVCoreBridge", "PVCoreObjCBridge", "PVEmulatorCore", "PVLogging", "PVPlists",
                .product(name: "PVCoreBridgeRetro", package: "PVCoreBridgeRetro")
            ],
            path: "PVEP128EmuCore",
            exclude: ["PVEP128EmuCore.mm", "PVEP128EmuCore.h"],
            resources: [.copy("Resources/Core.plist")]
        ),
        .target(
            name: "PVEP128EmuBridge",
            dependencies: [
                "libep128emu", "PVCoreBridge", "PVCoreObjCBridge",
                .product(name: "PVCoreBridgeRetro", package: "PVCoreBridgeRetro")
            ],
            path: "Sources/PVEP128EmuBridge",
            sources: ["PVEP128EmuCore.mm"],
            publicHeadersPath: "include",
            cxxSettings: [.unsafeFlags(["-fmodules", "-fcxx-modules"])],
            linkerSettings: [
                // The legacy bridge uses dlsym on this framework: retain all retro_* exports.
                .unsafeFlags(["-Xlinker", "-all_load"])
            ]
        ),
        .target(
            name: "libep128emu",
            path: "Sources/libep128emu",
            sources: [
                "upstream/core/core.cpp",
                "upstream/core/libretrodisp.cpp",
                "upstream/core/libretrosnd.cpp",
                "libretro_entry.cpp",
                "upstream/src/ay3_8912.cpp",
                "upstream/src/bplist.cpp",
                "upstream/src/cfg_db.cpp",
                "upstream/src/compress.cpp",
                "upstream/src/comprlib.cpp",
                "upstream/src/cpc464vm.cpp",
                "upstream/src/cpc_snap.cpp",
                "upstream/src/cpcdisk.cpp",
                "upstream/src/cpcio.cpp",
                "upstream/src/cpcmem.cpp",
                "upstream/src/cpcvideo.cpp",
                "upstream/src/crtc6845.cpp",
                "upstream/src/dave.cpp",
                "upstream/src/debuglib.cpp",
                "upstream/src/decompm2.cpp",
                "upstream/src/display.cpp",
                "upstream/src/dotconf.c",
                "upstream/src/emucfg.cpp",
                "upstream/src/ep128vm.cpp",
                "upstream/src/ep_fdd.cpp",
                "upstream/src/epmemcfg.cpp",
                "upstream/src/fdc765.cpp",
                "upstream/src/fileio.cpp",
                "upstream/src/ide.cpp",
                "upstream/src/ioports.cpp",
                "upstream/src/joystick.cpp",
                "upstream/src/memory.cpp",
                "upstream/src/nick.cpp",
                "upstream/src/pngwrite.cpp",
                "upstream/src/script.cpp",
                "upstream/src/sdext.cpp",
                "upstream/src/snapshot.cpp",
                "upstream/src/snd_conv.cpp",
                "upstream/src/soundio.cpp",
                "upstream/src/system.cpp",
                "upstream/src/tape.cpp",
                "upstream/src/tvc64vm.cpp",
                "upstream/src/tvc_snap.cpp",
                "upstream/src/tvcmem.cpp",
                "upstream/src/tvcvideo.cpp",
                "upstream/src/ula.cpp",
                "upstream/src/videorec.cpp",
                "upstream/src/vm.cpp",
                "upstream/src/vmthread.cpp",
                "upstream/src/wd177x.cpp",
                "upstream/src/zx128vm.cpp",
                "upstream/src/zx_snap.cpp",
                "upstream/src/zxioport.cpp",
                "upstream/src/zxmemory.cpp",
                "upstream/z80/z80.cpp",
                "upstream/z80/z80funcs2.cpp"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("upstream"), .headerSearchPath("upstream/core"),
                .headerSearchPath("upstream/src"), .headerSearchPath("upstream/z80"),
                .define("__LIBRETRO__", to: "1"),
                .define("EXCLUDE_SOUND_LIBS", to: "1"),
                .define("EP128EMU_LIBRETRO_CORE", to: "1")
            ],
            linkerSettings: [.linkedLibrary("z")]
        )
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)
