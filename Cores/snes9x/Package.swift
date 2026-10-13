// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Snes9x core sources: the 51 files PVSNES9x.xcodeproj's `snes9x` target compiles,
/// relative to `snes9x-src`. Everything else in that directory (GUI ports, desktop
/// audio/video drivers, filters, netplay, debugger) is never built.
let snes9xCoreSources: [String] = [
    "apu/apu.cpp",
    "apu/bapu/dsp/sdsp.cpp",
    "apu/bapu/smp/smp.cpp",
    "apu/bapu/smp/smp_state.cpp",
    "bml.cpp",
    "bsx.cpp",
    "c4.cpp",
    "c4emu.cpp",
    "cheats.cpp",
    "cheats2.cpp",
    "clip.cpp",
    "conffile.cpp",
    "controls.cpp",
    "cpu.cpp",
    "cpuexec.cpp",
    "cpuops.cpp",
    "crosshairs.cpp",
    "dma.cpp",
    "dsp.cpp",
    "dsp1.cpp",
    "dsp2.cpp",
    "dsp3.cpp",
    "dsp4.cpp",
    "fscompat.cpp",
    "fxemu.cpp",
    "fxinst.cpp",
    "gfx.cpp",
    "globals.cpp",
    "memmap.cpp",
    "movie.cpp",
    "msu1.cpp",
    "obc1.cpp",
    "ppu.cpp",
    "sa1.cpp",
    "sa1cpu.cpp",
    "sdd1.cpp",
    "sdd1emu.cpp",
    "seta.cpp",
    "seta010.cpp",
    "seta011.cpp",
    "seta018.cpp",
    "sha256.cpp",
    "snapshot.cpp",
    "snes9x.cpp",
    "spc7110.cpp",
    "srtc.cpp",
    "stream.cpp",
    "tile.cpp",
    "tileimpl-h2x1.cpp",
    "tileimpl-n1x1.cpp",
    "tileimpl-n2x1.cpp",
]

/// The Snes9x headers the bridge includes (`snes9x.h`, `apu.h`, ...), as search paths
/// relative to the bridge target directory (`PVSNES`).
let snes9xHeaderSearchPaths: [CXXSetting] = [
    .headerSearchPath("../snes9x-src"),
    .headerSearchPath("../snes9x-src/apu"),
    .headerSearchPath("../snes9x-src/apu/bapu"),
]

let package = Package(
    name: "PVCoreSNES9x",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // The Swift module is named PVSNES because Core.plist's PVPrincipleClass is
        // "PVSNES.PVSNES9xEmulatorCore"; the products keep the PVSNES9x names.
        .library(
            name: "PVSNES9x",
            targets: ["PVSNES"]),
        .library(
            name: "PVSNES9x-Dynamic",
            type: .dynamic,
            targets: ["PVSNES"]),
        .library(
            name: "PVSNES9x-Static",
            type: .static,
            targets: ["PVSNES"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),
        .package(name: "PVPrimitives", path: "../../PVPrimitives/"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),
    ],
    targets: [
        // MARK: ------- Core (Swift) ---------

        // Shares the PVSNES directory with PVSNES9xBridge; the two list disjoint files.
        .target(
            name: "PVSNES",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVPlists",
                "PVPrimitives",
                "PVSNES9xBridge",
                "libsnes9x",
                .product(name: "PVRcheevos", package: "PVRcheevos"),
                .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
            ],
            path: "PVSNES",
            exclude: [
                "Info.plist",
                "PVSNES.h",
                "SNES/PVSNESEmulatorCore.h",
                "SNES/PVSNESEmulatorCore.mm",
                "SNES/PVSNESEmulatorCore+LightGun.mm",
                "SNES/SNESOESupport.mm",
            ],
            sources: [
                "SNES/CoreOptions.swift",
                "SNES/CorePlist.swift",
                "SNES/CorePlist-Generated.swift",
                "SNES/PVSNESEmulatorCore.swift",
                "SNES/PVSNES9xEmulatorCore+RetroAchievements.swift",
            ],
            resources: [
                .process("Core.plist")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        // MARK: ------- Bridge (ObjC++) ---------

        .target(
            name: "PVSNES9xBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVObjCUtils",
                "libsnes9x",
            ],
            path: "PVSNES",
            exclude: [
                "Core.plist",
                "Info.plist",
                "PVSNES.h",
                "SNES/CoreOptions.swift",
                "SNES/CorePlist.swift",
                "SNES/CorePlist-Generated.swift",
                "SNES/PVSNESEmulatorCore.swift",
                "SNES/PVSNES9xEmulatorCore+RetroAchievements.swift",
            ],
            sources: [
                "SNES/PVSNESEmulatorCore.mm",
                "SNES/PVSNESEmulatorCore+LightGun.mm",
                "SNES/SNESOESupport.mm",
            ],
            publicHeadersPath: "SNES",
            cxxSettings: snes9xHeaderSearchPaths + [
                .unsafeFlags(["-fmodules", "-fcxx-modules"]),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),

        // MARK: ------- Emulator ---------

        // Snes9x, compiled from the Provenance-Emu/snes9x submodule. The file list and
        // include paths mirror the `snes9x` target of PVSNES9x.xcodeproj.
        .target(
            name: "libsnes9x",
            // Sources/libsnes9x/snes9x-src is a symlink to the submodule: a target's
            // public headers directory must live inside its own path.
            path: "Sources/libsnes9x",
            // Only `sources` is compiled; these are excluded so SwiftPM does not pick up
            // the desktop frontends' .lproj directories as localized resources.
            exclude: [
                "snes9x-src/common",
                "snes9x-src/data",
                "snes9x-src/docs",
                "snes9x-src/external",
                "snes9x-src/filter",
                "snes9x-src/gtk",
                "snes9x-src/jma",
                "snes9x-src/libretro",
                "snes9x-src/macosx",
                "snes9x-src/qt",
                "snes9x-src/unix",
                "snes9x-src/win32",
            ],
            sources: snes9xCoreSources.map { "snes9x-src/" + $0 },
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("snes9x-src"),
                .headerSearchPath("snes9x-src/apu"),
                .headerSearchPath("snes9x-src/apu/bapu"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx20
)
