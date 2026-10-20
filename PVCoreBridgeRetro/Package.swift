// swift-tools-version:6.0
import PackageDescription

// The Swift API depends on the ObjC frontend, which calls independent Swift helpers.
// Keeping those helpers below the frontend avoids a Swift/ObjC dependency cycle.
// Keep the legacy C runtime and ObjC bridge on identical feature/struct definitions.
let libretroFeatures: [CSetting] = [
    .define("__LIBRETRO__", to: "1"),
    .define("HAVE_THREADS", to: "1"),
    .define("HAVE_OPENGL", to: "1"),
    .define("HAVE_OPENGLES", to: "1"),
    .define("HAVE_OPENGLES2", to: "1"),
    .define("HAVE_OPENGLES3", to: "1"),
    .define("HAVE_VULKAN", to: "1"),
    .define("HAVE_GLSL", to: "1"),
    .define("GLES", to: "1"),
    .define("GLES2", to: "1"),
    .define("GLES3", to: "1"),
    .define("GLES31", to: "1"),
    .define("HAVE_CHEEVOS", to: "1"),
    .define("HAVE_RCHEEVOS", to: "1"),
    // Netplay is provided by PVNetplay; the compatibility runtime has no RetroArch netplay driver.
    .define("HAVE_NETWORK", to: "1"),
    .define("HAVE_CODEC_HW", to: "1"),
    .define("HAVE_NETWORKING", to: "1"),
    .define("HAVE_STDIN_CMD", to: "1"),
    .define("HAVE_COMMAND"),
    .define("HAVE_NETWORK_CMD", to: "1"),
    .define("HAVE_DYNAMIC", to: "1"),
    .define("HAVE_NETWORKGAMEPAD", to: "1"),
    .define("HAVE_ZLIB", to: "1"),
    .define("HAVE_ZARCH", to: "1"),
    .define("HAVE_GIT_VERSION", to: "1"),
    .define("HAVE_COMPRESSION", to: "1"),
    .define("HAVE_COREAUDIO"),
    .define("HAVE_DYLIB", to: "1"),
    .define("HAVE_COCOA", to: "1"),
    .define("HAVE_CORELOCATION"),
    .define("HAVE_COCOATOUCH"),
    .define("HAVE_LOCATION", to: "1"),
    .define("HAVE_CAMERA", to: "1"),
    .define("HAVE_HID", to: "1"),
    .define("HAVE_7ZIP"),
    // Built-in RetroArch media cores are not part of the compatibility runtime.
    .define("HAVE_LIBRETRODB"),
    .define("HAVE_CORETEXT"),
    .define("HAVE_AVFOUNDATION"),
    .define("HAVE_CDROM"),
    .define("HAVE_PATCH"),
    .define("HAVE_RPNG"),
    .define("HAVE_RBMP"),
    .define("HAVE_GFX_WIDGETS"),
    .define("HAVE_OVERLAY"),
    .define("HAVE_FILTERS_BUILTIN"),
    .define("NEED_DYNAMIC"),
    .define("DEBUG", .when(configuration: .debug))
]

let package = Package(
    name: "PVCoreBridgeRetro",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PVCoreBridgeRetro", type: .dynamic, targets: ["PVCoreBridgeRetro"]),
        .library(name: "PVLibRetro", targets: ["PVCoreBridgeRetro"])
    ],
    dependencies: [
        .package(path: "../PVAudio"),
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVCoreObjCBridge"),
        .package(path: "../PVEmulatorCore"),
        .package(path: "../PVLogging"),
        .package(path: "../PVNetplay"),
        .package(path: "../PVObjCUtils"),
        .package(path: "../PVPlists"),
        .package(path: "../PVPrimitives"),
        .package(path: "../PVSettings"),
        .package(path: "../PVSupport"),
        .package(path: "../PVArchiving"),
        .package(path: "../PVRcheevos"),
        .package(path: "../PVJIT"),
        .package(path: "../MoltenVK"),
        .package(url: "https://github.com/Provenance-Emu/PVSystems.git", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2")
    ],
    targets: [
        .target(
            name: "PVCoreBridgeRetro",
            dependencies: [
                "PVLibRetroBridge", "PVLibRetroSupport", "PVCoreBridge", "PVCoreObjCBridge",
                "PVEmulatorCore", "PVLogging", "PVSettings", "PVSupport", "PVArchiving", "PVNetplay", "PVPrimitives",
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "PVSystems", package: "PVSystems")
            ],
            path: "Sources/PVLibRetro",
            exclude: [
                "PVLibRetroCore+Audio.m",
                "PVLibRetroCore+Cheats.m",
                "PVLibRetroCore+Controls.m",
                "PVLibRetroCore+Options.m",
                "PVLibRetroCore+Saves.m",
                "PVLibRetroCore+Video.m",
                "PVLibRetroCore.m",
                "PVLibRetroGLESCore.m",
                "PVRetroArchStateDecoder.m",
                "PVThinCoreCallGate.m",
                "PVThinLibretroFrontend.mm",
                "PVRetroArchStateDecoder.h",
                "PVThinLibretroFrontend.h",
                "PVThinCoreCallGate.h",
                "PVLibRetroCore.h",
                "PVLibRetroGLESCore.h",
                "PVLibRetro+JIT.swift",
                "PVLibRetroRumbleHelper.swift",
                "SystemIdentifier+ObjCBridge.swift",
                "ThinVFSDiskImagePolicy.swift",
                "ThinContentArchiveResolver.swift",
                "include",
                "PVCoreBridgeRetro.h"
            ],
            sources: [
                "PVThinLibretroCore+Controls.swift",
                "PVThinLibretroCore+Features.swift",
                "PVThinLibretroCore+LayoutVariant.swift",
                "PVThinLibretroCore+MIDI.swift",
                "PVThinLibretroCore+Netplay.swift",
                "PVThinLibretroCore+Palette.swift",
                "PVThinLibretroCore+Scaling.swift",
                "PVThinLibretroCore+SystemFiles.swift",
                "PVThinLibretroCore.swift",
                "RelativeMouseScaler.swift",
                "ThinSystemFileManifest.swift",
                "ThinSystemFileProvisioner.swift",
                "Exports.swift"
            ],
            resources: [.copy("Resources/hatari.cfg")],
            swiftSettings: [.define("HAVE_DYNAMIC")]
        ),
        .target(
            name: "PVLibRetroSupport",
            dependencies: [
                "PVCoreBridge", "PVLogging", "PVArchiving",
                .product(name: "JITManager", package: "PVJIT", condition: .when(platforms: [.iOS, .macOS])),
                .product(name: "PVSystems", package: "PVSystems")
            ],
            path: "Sources/PVLibRetro",
            exclude: [
                "PVLibRetroCore+Audio.m",
                "PVLibRetroCore+Cheats.m",
                "PVLibRetroCore+Controls.m",
                "PVLibRetroCore+Options.m",
                "PVLibRetroCore+Saves.m",
                "PVLibRetroCore+Video.m",
                "PVLibRetroCore.m",
                "PVLibRetroGLESCore.m",
                "PVRetroArchStateDecoder.m",
                "PVThinCoreCallGate.m",
                "PVThinLibretroFrontend.mm",
                "PVRetroArchStateDecoder.h",
                "PVThinLibretroFrontend.h",
                "PVThinCoreCallGate.h",
                "PVLibRetroCore.h",
                "PVLibRetroGLESCore.h",
                "PVThinLibretroCore+Controls.swift",
                "PVThinLibretroCore+Features.swift",
                "PVThinLibretroCore+LayoutVariant.swift",
                "PVThinLibretroCore+MIDI.swift",
                "PVThinLibretroCore+Netplay.swift",
                "PVThinLibretroCore+Palette.swift",
                "PVThinLibretroCore+Scaling.swift",
                "PVThinLibretroCore+SystemFiles.swift",
                "PVThinLibretroCore.swift",
                "RelativeMouseScaler.swift",
                "ThinSystemFileManifest.swift",
                "ThinSystemFileProvisioner.swift",
                "Exports.swift",
                "include",
                "Resources"
            ],
            sources: [
                "PVLibRetro+JIT.swift",
                "PVLibRetroRumbleHelper.swift",
                "SystemIdentifier+ObjCBridge.swift",
                "ThinVFSDiskImagePolicy.swift",
                "ThinContentArchiveResolver.swift"
            ]
        ),
        .target(
            name: "PVLibRetroBridge",
            dependencies: [
                "PVLibRetroSupport", "libretro", "PVAudio", "PVCoreBridge", "PVCoreObjCBridge",
                "PVLogging", "PVSettings", "PVSupport", "PVObjCUtils",
                .product(name: "CRcheevos", package: "PVRcheevos"),
                .product(name: "MoltenVK", package: "MoltenVK")
            ],
            path: "Sources/PVLibRetro",
            exclude: [
                "PVThinLibretroCore+Controls.swift",
                "PVThinLibretroCore+Features.swift",
                "PVThinLibretroCore+LayoutVariant.swift",
                "PVThinLibretroCore+MIDI.swift",
                "PVThinLibretroCore+Netplay.swift",
                "PVThinLibretroCore+Palette.swift",
                "PVThinLibretroCore+Scaling.swift",
                "PVThinLibretroCore+SystemFiles.swift",
                "PVThinLibretroCore.swift",
                "RelativeMouseScaler.swift",
                "ThinContentArchiveResolver.swift",
                "ThinSystemFileManifest.swift",
                "ThinSystemFileProvisioner.swift",
                "PVLibRetro+JIT.swift",
                "PVLibRetroRumbleHelper.swift",
                "SystemIdentifier+ObjCBridge.swift",
                "ThinVFSDiskImagePolicy.swift",
                "Exports.swift",
                "Resources"
            ],
            sources: [
                "PVLibRetroCore+Audio.m",
                "PVLibRetroCore+Cheats.m",
                "PVLibRetroCore+Controls.m",
                "PVLibRetroCore+Options.m",
                "PVLibRetroCore+Saves.m",
                "PVLibRetroCore+Video.m",
                "PVLibRetroCore.m",
                "PVLibRetroGLESCore.m",
                "PVRetroArchStateDecoder.m",
                "PVThinCoreCallGate.m",
                "PVThinLibretroFrontend.mm"
            ],
            publicHeadersPath: "include",
            cSettings: libretroFeatures + [
                .headerSearchPath("../retro/libretro-common/include"),
                .headerSearchPath("../retro"),
                .headerSearchPath("../retro/gfx"),
                .headerSearchPath("../ExternalHeaders/MoltenVK")
            ],
            cxxSettings: [
                // The Objective-C++ frontend imports Swift and Clang modules.
                .unsafeFlags(["-fmodules", "-fcxx-modules"])
            ],
            linkerSettings: [
                // Keep Objective-C categories when this target is linked through the Swift product.
                .unsafeFlags(["-Xlinker", "-ObjC"]),
                .linkedFramework("OpenGL", .when(platforms: [.macOS])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("Metal"), .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"), .linkedFramework("Accelerate"),
                .linkedFramework("CoreMIDI", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("Network"), .linkedLibrary("z")
            ]
        ),
        // Only symbols used by PVLibRetroCoreBridge: threading, dylib loading, keyboard maps and the dummy core.
        .target(
            name: "libretro",
            dependencies: ["PVObjCUtils"],
            path: "Sources/retro",
            sources: [
                "libretro-common/rthreads/rthreads.c",
                "libretro-common/dynamic/dylib.c",
                "cores/dynamic_dummy.c",
                "input/input_keymaps.c"
            ],
            publicHeadersPath: "include",
            cSettings: libretroFeatures + [
                .headerSearchPath("."),
                .headerSearchPath("gfx"),
                .headerSearchPath("libretro-common/include"),
                .headerSearchPath("../ExternalHeaders/MoltenVK")
            ],
            linkerSettings: [.linkedLibrary("iconv"), .linkedLibrary("z")]
        ),
        .testTarget(
            name: "PVLibRetroTests",
            dependencies: ["PVCoreBridgeRetro", "PVLibRetroSupport", "PVArchiving"],
            path: "Tests/PVLibRetroTests"
        )
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
