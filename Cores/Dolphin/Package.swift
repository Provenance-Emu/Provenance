// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Dolphin wrapper shared by the shipping project and Tuist. Prepare the native
// XCFramework with `make prepare-dolphin` before resolving the workspace.
//
// Layout
//   PVlibDolphin     binaryTarget over dolphin-ios/build/xcframework/PVlibDolphin.xcframework, the
//                    emulator itself (CMake, built out of tree). The xcframework is a BUILD
//                    ARTEFACT: `Scripts/cores/build_slice.py dolphin <slice>` produces it from the
//                    slice cache, and SwiftPM refuses to load this package while it is missing.
//                    `make dev-dolphin` runs that first (see Makefile, DEV_PREBUILT_CORES).
//   PVDolphinBridge  ObjC++ (PVDolphinCoreBridge and its categories). Reads Dolphin's C++ headers
//                    straight from the dolphin-ios submodule, like the xcodeproj does.
//   PVDolphin        Swift. Named PVDolphin because Core.plist's PVPrincipleClass is
//                    "PVDolphin.PVDolphinCore". Both targets share the package directory and list
//                    disjoint files (the Cores/snes9x layout); the files stay where the xcodeproj
//                    expects them.
//
// Simulators and slices
//   The xcodeproj excludes every source on simulator SDKs and compiles only Cores/Debug/PVDebug.c
//   (EXCLUDED_SOURCE_FILE_NAMES in BuildFlags.xcconfig). A package cannot do that, and has no use
//   for the stub: it builds the bridge for whatever platform Xcode asks for. SwiftPM then needs
//   that platform's slice inside the xcframework, and `build_slice.py` packs only the slices that
//   exist. Building for a platform whose slice is missing fails at link time with "no library for
//   this platform was found in PVlibDolphin.xcframework". Dolphin is a device core: build ios or
//   tvos, not the simulators.
//
// Not expressible in SwiftPM
//   - `$(SRCROOT)` and `[arch=arm64]`/`[sdk=...]` conditions: the settings below apply to every
//     platform the package builds for. All of them are arm64.
//   - `-frename-registers` (a GCC-only flag clang ignores) is dropped.
//   - `GCC_PREFIX_HEADER`: PVDolphinCore-Prefix.pch is not referenced by the xcodeproj either.
//   - `SKIP_INSTALL`/`INSTALL_PATH`/`LD_RUNPATH_SEARCH_PATHS` framework packaging: Xcode wraps the
//     `-Dynamic` product itself.
//   - Sys/ is copied through Resources/Sys, a package-local symlink into the submodule.
//     Both Config/ and Sys/ belong to the bridge resource bundle.

// MARK: ------- Shared -------

/// Headers `PVDolphinCore.mm` and friends include, relative to the package directory.
let dolphinHeaderPaths: [String] = [
    "PVDolphinCore/Core",
    "dolphin-ios/Source/Core/Core/IOS",
    "dolphin-ios/Source/Core",
    "dolphin-ios/Source",
    "dolphin-ios/Externals/fmt/fmt/include",
    "dolphin-ios/Externals/soundtouch",
    "dolphin-ios/Externals/mbedtls/include",
    "dolphin-ios/Externals/Vulkan/Include",
    "dolphin-ios/Externals/Vulkan-Headers/include",
    "dolphin-ios/Externals/VulkanMemoryAllocator/include",
    "dolphin-ios/Externals/SFML/SFML/include",
    "dolphin-ios/Externals/enet/enet/include",
]

/// GCC_PREPROCESSOR_DEFINITIONS (target + BuildFlags.xcconfig), name and value.
let dolphinDefines: [(String, String)] = [
    ("USE_GDBSTUB", "1"),
    ("NONJAILBROKEN", "1"),
    ("PB_ENABLE_MALLOC", "1"),
    ("PB_NO_PACKED_STRUCTS", "1"),
    ("PB_FIELD_32BIT", "1"),
    ("GLES_SILENCE_DEPRECATIONS", "1"),
    ("_ARCH_64", "1"),
    ("_M_ARM_64", "1"),
    ("IPHONEOS", "1"),
    ("TARGET_IPHONE", "1"),
]

/// OTHER_CFLAGS from BuildFlags.xcconfig. `-include DolphinCxxCompat.h` is found through
/// `dolphinHeaderPaths` (SwiftPM runs the compiler from a directory that makes a relative
/// file path unreliable; a bare header name goes through the search path).
let dolphinCompilerFlags: [String] = [
    "-fno-operator-names",
    "-fno-rtti",
    "-ftree-vectorize",
    "-fno-strict-aliasing",
    "-fpermissive",
    "-fsingle-precision-constant",
    "-DTARGET_NO_NIXPROF",
    "-fmodules",
    "-fcxx-modules",
    "-Wno-module-import-in-extern-c",
    "-include", "DolphinCxxCompat.h",
    "-march=armv8-a+simd",
    "-mcpu=apple-a10",
    "-mtune=apple-a15",
]

let dolphinCSettings: [CSetting] = dolphinHeaderPaths.map { CSetting.headerSearchPath($0) }
    + dolphinDefines.map { CSetting.define($0.0, to: $0.1) }

let dolphinCXXSettings: [CXXSetting] = dolphinHeaderPaths.map { CXXSetting.headerSearchPath($0) }
    + dolphinDefines.map { CXXSetting.define($0.0, to: $0.1) }
    + [.unsafeFlags(dolphinCompilerFlags)]

/// Preserve the legacy unexported-symbol list and rpaths through the Swift linker driver. PVlibDolphin and
/// Azahar both static-link glslang; hiding Dolphin's keeps dyld from coalescing the two.
let dolphinLinkerFlags: [String] = [
    "-ObjC",
    "-rpath", "@loader_path",
    "-rpath", "@loader_path/../Frameworks/PVlibDolphin.framework",
    "-rpath", "@executable_path/../Frameworks/PVlibDolphin.framework",
    "-unexported_symbol", "_glslang*", "-unexported_symbol", "_SPIRV*",
    "-unexported_symbol", "_TBuiltInResource*", "-unexported_symbol", "_EShLanguage*",
    "-unexported_symbol", "__ZN7glslang*", "-unexported_symbol", "__ZN5SPIRV*",
    "-unexported_symbol", "__ZN4spv*", "-unexported_symbol", "__Z*glslang*",
    "-unexported_symbol", "__Z*SPIRV*", "-unexported_symbol", "__Z*spv*",
].flatMap { ["-Xlinker", $0] }

/// The Frameworks build phase of the PVDolphin target (macOS-only OpenGL.framework omitted).
let dolphinSystemFrameworks: [String] = [
    "Security", "GLKit", "QuartzCore", "CoreGraphics", "Foundation", "SystemConfiguration",
    "OpenGLES", "MetalKit", "Metal", "GameController", "CoreHaptics", "UIKit",
    "CoreAudio", "AudioToolbox", "AVFoundation",
]

let dolphinLinkerSettings: [LinkerSetting] = dolphinSystemFrameworks.map { LinkerSetting.linkedFramework($0) } + [
    .linkedFramework("CoreAudioKit", .when(platforms: [.iOS]))
]
    + [
        .linkedLibrary("c++"),
        .linkedLibrary("z"),
        .linkedLibrary("bz2"),
        .unsafeFlags(dolphinLinkerFlags),
    ]

/// Directories of the package root that are not part of either target. `dolphin-ios` and `lib`
/// hold the submodule and its build trees; walking them would take SwiftPM minutes.
let dolphinLocalBuildPaths = ["build", "venv", "PVDolphin.xcodeproj"].filter {
    FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent($0).path)
}
let dolphinNonTargetPaths: [String] = dolphinLocalBuildPaths + [
    "dolphin-ios",
    "lib",
    "cmake",
    "build_dolphin_core.py",
    "build_dolphin_core.sh",
    "convert_to_object_libs.sh",
    "toolchain_patch.diff",
    // Sources the xcodeproj does not compile (OpenEmu leftovers, an unlisted mixer, notes).
    "PVDolphinCore/DolphinGameCore.h",
    "PVDolphinCore/DolphinGameCore.mm",
    "PVDolphinCore/PVDolphin.mm",
    "PVDolphinCore/Core/Mixer.cpp",
    "PVDolphinCore/Core/CachedInterpreterOptimizations.md",
    "PVDolphinCore/Core/PVDolphinCore-Prefix.pch",
]

/// Compiled by the PVDolphin target of PVDolphin.xcodeproj (minus Cores/Debug/PVDebug.c, the
/// simulator stub).
let dolphinBridgeSources: [String] = [
    "FastmemUtil.m",
    "Cheats_ActionReplay.mm",
    "Cheats_GeckoCode.mm",
    "PVDolphinCore.mm",
    "PVDolphinCore+Audio.mm",
    "PVDolphinCore+Cheats.mm",
    "PVDolphinCore+Controls.mm",
    "PVDolphinCore+Netplay.mm",
    "PVDolphinCore+RetroAchievements.mm",
    "PVDolphinCore+Saves.mm",
    "PVDolphinCore+Video.mm",
    "VulkanLoader.cpp",
].map { "PVDolphinCore/Core/" + $0 }

let dolphinSwiftSources: [String] = [
    "CorePlist.swift",
    "CorePlist-Generated.swift",
    "DolphinOGLViewController.swift",
    "DolphinVulkanViewController.swift",
    "PVDolphinCore.swift",
    "PVDolphinCore+PVNetplayCapable.swift",
    "PVDolphinCore+RetroAchievements.swift",
    "PVDolphinCoreOptions.swift",
].map { "PVDolphinCore/Core/" + $0 }

// MARK: ------- Targets -------

let emulatorLibrary: Target = .binaryTarget(
    name: "PVlibDolphin",
    path: "dolphin-ios/build/xcframework/PVlibDolphin.xcframework"
)

let bridgeTarget: Target = .target(
    name: "PVDolphinBridge",
    dependencies: [
        "PVlibDolphin",
        "PVEmulatorCore",
        "PVCoreBridge",
        "PVCoreObjCBridge",
        "PVLogging",
        "PVSettings",
        "PVSupport",
    ],
    path: ".",
    exclude: dolphinNonTargetPaths + ["PVDolphin"],
    sources: dolphinBridgeSources,
    resources: [
        .copy("Resources/Config"),
        .copy("Resources/Sys"),
    ],
    // The public headers are listed by Sources/PVDolphinBridge/include/module.modulemap: three
    // headers in PVDolphinCore/Core are C++ only and must stay out of the module Swift imports.
    publicHeadersPath: "Sources/PVDolphinBridge/include",
    cSettings: dolphinCSettings,
    cxxSettings: dolphinCXXSettings,
    linkerSettings: dolphinLinkerSettings
)

let swiftTarget: Target = .target(
    name: "PVDolphin",
    dependencies: [
        "PVDolphinBridge",
        "PVEmulatorCore",
        "PVCoreBridge",
        "PVCoreObjCBridge",
        "PVAudio",
        "PVLogging",
        "PVPlists",
        "PVPrimitives",
        "PVSettings",
        "PVShaders",
        "PVSupport",
        "PVNetplay",
        .product(name: "Defaults", package: "Defaults"),
        .product(name: "PVRcheevos", package: "PVRcheevos"),
        .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
    ],
    path: ".",
    exclude: dolphinNonTargetPaths + ["PVDolphin/Info.plist", "PVDolphin/PVDolphin.h", "Resources", "Sources"],
    sources: dolphinSwiftSources,
    resources: [
        .process("PVDolphin/Core.plist"),
    ]
)

let package = Package(
    name: "PVCoreDolphin",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
    ],
    products: [
        // No Static product: PVlibDolphin.xcframework holds dynamic frameworks.
        .library(
            name: "PVDolphin",
            targets: ["PVDolphin"]),
        .library(
            name: "PVDolphin-Dynamic",
            type: .dynamic,
            targets: ["PVDolphin"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVSettings"),
        .package(path: "../../PVShaders"),
        .package(name: "PVNetplay", path: "../../PVNetplay"),
        .package(name: "PVPrimitives", path: "../../PVPrimitives/"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2"),
    ],
    targets: [
        emulatorLibrary,
        bridgeTarget,
        swiftTarget,
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .cxx2b
)
