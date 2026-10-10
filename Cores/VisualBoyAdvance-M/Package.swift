// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// VBA-M core sources compiled from the Provenance-Emu/visualboyadvance-m
/// submodule (branch Provenance-master, tag v2.2.3), relative to
/// Sources/libvisualboyadvance. This is the GBA half of upstream's
/// `vbam-core` CMake target (src/core/CMakeLists.txt + src/core/base and
/// src/core/apu), built as upstream's desktop (non-libretro) core so save
/// states and battery saves stay file based. Left out, as in upstream builds
/// without ENABLE_DEBUGGER/ENABLE_LINK: the debugger (gbaRemote, gbaElf,
/// gbaCpuArmDis, debugger-expr-*), link cable (gbaLink, gbaSockClient), the
/// `fex` archive reader (replaced by provenance/file_util_provenance.cpp) and
/// the Game Boy core (this core only plays GBA). When bumping the submodule,
/// re-sync this list with those CMake files.
let vbamCoreSources: [String] = [
    // core/apu
    "visualboyadvance-m/src/core/apu/Blip_Buffer.cpp",
    "visualboyadvance-m/src/core/apu/Effects_Buffer.cpp",
    "visualboyadvance-m/src/core/apu/Gb_Apu.cpp",
    "visualboyadvance-m/src/core/apu/Gb_Apu_State.cpp",
    "visualboyadvance-m/src/core/apu/Gb_Oscs.cpp",
    "visualboyadvance-m/src/core/apu/Multi_Buffer.cpp",
    // core/base (file_util_desktop.cpp -> provenance/file_util_provenance.cpp)
    "visualboyadvance-m/src/core/base/file_util_common.cpp",
    "visualboyadvance-m/src/core/base/image_util.cpp",
    "visualboyadvance-m/src/core/base/internal/file_util_internal.cpp",
    "visualboyadvance-m/src/core/base/internal/memgzio.c",
    // core/gba
    "visualboyadvance-m/src/core/gba/gba.cpp",
    "visualboyadvance-m/src/core/gba/gbaCheatSearch.cpp",
    "visualboyadvance-m/src/core/gba/gbaCheats.cpp",
    "visualboyadvance-m/src/core/gba/gbaCpuArm.cpp",
    "visualboyadvance-m/src/core/gba/gbaCpuThumb.cpp",
    "visualboyadvance-m/src/core/gba/gbaEeprom.cpp",
    "visualboyadvance-m/src/core/gba/gbaFlash.cpp",
    "visualboyadvance-m/src/core/gba/gbaGfx.cpp",
    "visualboyadvance-m/src/core/gba/gbaGlobals.cpp",
    "visualboyadvance-m/src/core/gba/gbaMode0.cpp",
    "visualboyadvance-m/src/core/gba/gbaMode1.cpp",
    "visualboyadvance-m/src/core/gba/gbaMode2.cpp",
    "visualboyadvance-m/src/core/gba/gbaMode3.cpp",
    "visualboyadvance-m/src/core/gba/gbaMode4.cpp",
    "visualboyadvance-m/src/core/gba/gbaMode5.cpp",
    "visualboyadvance-m/src/core/gba/gbaPrint.cpp",
    "visualboyadvance-m/src/core/gba/gbaRtc.cpp",
    "visualboyadvance-m/src/core/gba/gbaSound.cpp",
    "visualboyadvance-m/src/core/gba/internal/gbaBios.cpp",
    "visualboyadvance-m/src/core/gba/internal/gbaEreader.cpp",
    "visualboyadvance-m/src/core/gba/internal/gbaSram.cpp",
    // Provenance glue
    "provenance/file_util_provenance.cpp",
    "provenance/legacy_state.cpp",
]

/// Defines shared by the core and every target that includes its headers, so
/// structs like `memoryMap` and `EmulatedSystem` have one layout. Mirrors
/// upstream's libretro Makefile.common minus `__LIBRETRO__`.
let vbamCDefines: [CSetting] = [
    .define("C_CORE"),
    .define("FINAL_VERSION"),
    .define("NO_LINK"),
    .define("TILED_RENDERING"),
]
let vbamCXXDefines: [CXXSetting] = [
    .define("C_CORE"),
    .define("FINAL_VERSION"),
    .define("NO_LINK"),
    .define("TILED_RENDERING"),
]

let package = Package(
    name: "PVCoreVisualBoyAdvance",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
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
        .package(path: "../../PVPrimitives"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),
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
                "PVPrimitives",
                "PVVisualBoyAdvanceBridge",
                "PVVisualBoyAdvanceOptions",
                "libvisualboyadvance",
                .product(name: "PVRcheevos", package: "PVRcheevos"),
                .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
            ],
            resources: [
                .process("Resources/Core.plist"),
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
                .product(name: "CRcheevos", package: "PVRcheevos"),
            ],
            resources: [
                .copy("Resources/vba-over.ini")
            ],
            cSettings: vbamCDefines + [
                .define("HAVE_RCHEEVOS", to: "1"),
                .headerSearchPath("../libvisualboyadvance/visualboyadvance-m/src"),
            ],
            cxxSettings: vbamCXXDefines + [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ]),
                .define("HAVE_RCHEEVOS", to: "1"),
                .headerSearchPath("../libvisualboyadvance/visualboyadvance-m/src"),
                .headerSearchPath("../libvisualboyadvance"),
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
        // VBA-M 2.2.3 core from the visualboyadvance-m submodule; see
        // `vbamCoreSources`. Only `sources` is compiled; the excludes keep
        // SwiftPM from treating the frontends' assets as resources.
        .target(
            name: "libvisualboyadvance",
            exclude: [
                "visualboyadvance-m/cmake",
                "visualboyadvance-m/data",
                "visualboyadvance-m/doc",
                "visualboyadvance-m/po",
                "visualboyadvance-m/tools",
                "visualboyadvance-m/third_party",
                "visualboyadvance-m/src/art",
                "visualboyadvance-m/src/components",
                "visualboyadvance-m/src/debian",
                "visualboyadvance-m/src/libretro",
                "visualboyadvance-m/src/sdl",
                "visualboyadvance-m/src/vita",
                "visualboyadvance-m/src/wx",
                "visualboyadvance-m/src/core/fex",
                "visualboyadvance-m/src/core/gb",
                "visualboyadvance-m/src/core/test",
                "visualboyadvance-m/src/core/base/test",
            ],
            sources: vbamCoreSources,
            publicHeadersPath: "include",
            packageAccess: true,
            cSettings: vbamCDefines + [
                .headerSearchPath("visualboyadvance-m/src"),
            ],
            cxxSettings: vbamCXXDefines + [
                .headerSearchPath("visualboyadvance-m/src"),
                // stb_image_write.h for core/base/image_util.cpp
                .headerSearchPath("visualboyadvance-m/third_party/include/stb"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        // MARK: --------- Tests -----------
        .testTarget(
            name: "PVVisualBoyAdvanceTests",
            dependencies: ["PVVisualBoyAdvance"],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .c99,
    cxxLanguageStandard: .gnucxx17
)
