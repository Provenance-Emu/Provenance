// swift-tools-version:6.0

import Foundation
import PackageDescription

// PVAzahar as a SwiftPM package (the Tuist dev workspace consumes PVAzahar-Dynamic).
// PVAzahar.xcodeproj stays the shipping build; this manifest mirrors its PVAzahar target.
//
// Targets:
//   PVAzahar        Swift; module name = Core.plist's PVPrincipleClass prefix ("PVAzahar.PVAzaharCore").
//   PVAzaharBridge  ObjC++ bridge + C++ glue. It never imports the Swift module (the render view, user
//                   directory and mute-switch policy are pushed in by PVAzaharCore), so there is no cycle.
//   PVlibAzahar     the emulator: a static-framework .xcframework over the slice cache, produced by
//                   `python3 Scripts/cores/build_slice.py azahar <slice> --xcframework` (make dev-generate).
//
// Differences from the xcodeproj that SwiftPM cannot express:
// - No x86_64 simulator slice. PVlibAzahar is arm64-only and SwiftPM has no arch-conditioned linker flags
//   (the xcodeproj links x86_64 with `-undefined dynamic_lookup`). Build arm64 only: the focused app
//   excludes x86_64 for simulator SDKs and `make dev-azahar` passes ARCHS=arm64.
// - Headers come from one slice of the xcframework, not the slice being built (SwiftPM cannot condition on
//   device vs simulator). The Headers/ trees of the ios, ios-sim and tvos-sim slices are identical.
// - The xcframework must exist when the package graph resolves; Xcode resolves binary targets before any
//   build phase runs, so no build-time aggregate can produce it. Without it the manifest drops the binary
//   target and the bridge fails with an #error that says how to build it (other focused apps still resolve).
//   SwiftPM caches manifest evaluation by manifest contents, not by what the manifest reads from disk
//   (checked with `swift package dump-package`: stale until `--manifest-cache none`). After producing the
//   xcframework, reset package caches (Xcode: File > Packages > Reset Package Caches) if the bridge still
//   stops at the "PVlibAzahar.xcframework is missing" #error.

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let xcframework = "build/xcframework/PVlibAzahar.xcframework"

/// The first slice of the xcframework that has azahar's headers (-idirafter, as in the xcodeproj).
let azaharHeaders: String? = ["ios-arm64", "ios-arm64-simulator", "tvos-arm64", "tvos-arm64-simulator"]
    .map { "\(packageDir)/\(xcframework)/\($0)/PVlibAzahar.framework/Headers" }
    .first { FileManager.default.fileExists(atPath: $0) }
let libraryPresent = azaharHeaders != nil
    && FileManager.default.fileExists(atPath: "\(packageDir)/\(xcframework)/Info.plist")

/// GCC_PREPROCESSOR_DEFINITIONS of the xcodeproj, each defined to 1.
let defines: [String] = [
    "ENABLE_VULKAN",
    "HAVE_COREAUDIO",
    "HAVE_FASTINTERP",
    "VK_NO_PROTOTYPES",
    "VULKAN_HPP_DISPATCH_LOADER_DYNAMIC",
    "VULKAN_HPP_NO_EXCEPTIONS",
] + (libraryPresent ? [] : ["PVAZAHAR_LIBRARY_MISSING"])

/// azahar headers are searched last: azahar's network/network.h would otherwise satisfy the SDK's
/// <Network/Network.h> on a case-insensitive volume. Only its network/ dir goes on -I (included as
/// "network.h"). Never include azahar's core/hle/service/nwm/nwm_uds.h (see CLAUDE.md).
let headerFlags: [String] = azaharHeaders.map { ["-idirafter", $0, "-I", "\($0)/network"] } ?? []

let bridgeCFlags: [String] = headerFlags
let bridgeCXXFlags: [String] = [
    "-fmodules",
    "-fcxx-modules",   // the ObjC++ glue does @import PVCoreBridge
    "-fvisibility=hidden",
    "-fvisibility-inlines-hidden",
    "-Wno-shorten-64-to-32",
    "-Wno-deprecated-declarations",
] + headerFlags

/// Keeps every C++ symbol private to this image: dyld coalesces exported weak definitions across images,
/// and PVlibDolphin's glslang/fmt instantiations crashed azahar's shader compiler (unexported_symbols.txt).
let linkerFlags: [String] = [
    "-ObjC",
    "-Xlinker", "-unexported_symbols_list",
    "-Xlinker", "\(packageDir)/unexported_symbols.txt",
]

/// Paths every target leaves out; each target then lists only its own files in `sources`.
let sharedExcludes: [String] = [
    "azahar",
    "cmake",
    "Tests",
    "PVAzahar.xcodeproj",
    "PVAzahar/Info.plist",
    "PVAzahar/PVAzahar.h",
    "PATCHES.md",
    "build_azahar_core.py",
    "project.yml",
    "swiftgen.yml",
    "unexported_symbols.txt",
] + (FileManager.default.fileExists(atPath: "\(packageDir)/build") ? ["build"] : [])   // gitignored output

let swiftSources: [String] = [
    "PVAzaharCore/CorePlist.swift",
    "PVAzaharCore/CorePlist-Generated.swift",
    "PVAzaharCore/PVAzaharCore.swift",
    "PVAzaharCore/PVAzaharCoreOptions.swift",
    "PVAzaharCore/PVAzaharDataMigrator.swift",
    "PVAzaharCore/PVAzaharRenderView.swift",
]

let bridgeSources: [String] = [
    "PVAzaharCore/PVAzaharCoreBridge.mm",
    "PVAzaharCore/PVAzaharCoreBridge+Audio.mm",
    "PVAzaharCore/PVAzaharCoreBridge+Cheats.mm",
    "PVAzaharCore/PVAzaharCoreBridge+Controls.mm",
    "PVAzaharCore/PVAzaharCoreBridge+Saves.mm",
    "PVAzaharCore/PVAzaharCoreBridge+Video.mm",
    "PVAzaharCore/Glue/AzaharAppleUtils.mm",
    "PVAzaharCore/Glue/AzaharCamera.mm",
    "PVAzaharCore/Glue/AzaharEmuWindow.mm",
    "PVAzaharCore/Glue/AzaharGraphicsContext.mm",
    "PVAzaharCore/Glue/AzaharInput.cpp",
]

let bridgeHeaders: [String] = [
    "PVAzaharCore/PVAzaharCoreBridge.h",
    "PVAzaharCore/PVAzaharCoreBridge+Private.h",
    "PVAzaharCore/PVAzaharCoreBridge+Video.h",
    "PVAzaharCore/Glue/AzaharCamera.h",
    "PVAzaharCore/Glue/AzaharEmuWindow.h",
    "PVAzaharCore/Glue/AzaharGraphicsContext.h",
    "PVAzaharCore/Glue/AzaharInput.h",
]

let systemLinks: [LinkerSetting] = [
    .linkedFramework("Metal"),
    .linkedFramework("QuartzCore"),
    .linkedFramework("AudioToolbox"),
    .linkedFramework("CoreAudio"),
    .linkedFramework("AVFoundation"),
    .linkedFramework("IOSurface"),
    .linkedLibrary("z"),
    .linkedLibrary("c++"),
]

let package = Package(
    name: "PVAzahar",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "PVAzahar", targets: ["PVAzahar"]),
        .library(name: "PVAzahar-Dynamic", type: .dynamic, targets: ["PVAzahar"]),
    ],
    dependencies: [
        .package(path: "../../PVAudio"),
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVJIT"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVPrimitives"),
        .package(path: "../../PVSettings"),
        .package(path: "../../PVSupport"),
    ],
    targets: [
        // MARK: Core (Swift)

        .target(
            name: "PVAzahar",
            dependencies: [
                "PVAzaharBridge",
                .product(name: "PVCoreBridge", package: "PVCoreBridge"),
                .product(name: "PVCoreObjCBridge", package: "PVCoreObjCBridge"),
                .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                .product(name: "PVLogging", package: "PVLogging"),
                .product(name: "PVPlists", package: "PVPlists"),
                .product(name: "PVPrimitives", package: "PVPrimitives"),
                .product(name: "PVSettings", package: "PVSettings"),
                .product(name: "PVSupport", package: "PVSupport"),
            ],
            path: ".",
            exclude: sharedExcludes + bridgeSources + bridgeHeaders + ["SwiftPM"],
            sources: swiftSources,
            resources: [
                .process("PVAzahar/Core.plist"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),   // SWIFT_OBJC_INTEROP_MODE = objcxx in the xcodeproj
            ]
        ),

        // MARK: Bridge (ObjC++)

        .target(
            name: "PVAzaharBridge",
            dependencies: [
                .product(name: "PVAudio", package: "PVAudio"),
                .product(name: "PVCoreBridge", package: "PVCoreBridge"),
                .product(name: "PVCoreObjCBridge", package: "PVCoreObjCBridge"),
                .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                .product(name: "PVJIT", package: "PVJIT"),
                .product(name: "PVLogging", package: "PVLogging"),
                .product(name: "PVObjCUtils", package: "PVObjCUtils"),
                .product(name: "PVSupport", package: "PVSupport"),
            ] + (libraryPresent ? ["PVlibAzahar"] : []),
            path: ".",
            exclude: sharedExcludes + swiftSources + ["PVAzahar/Core.plist"],
            sources: bridgeSources + bridgeHeaders,
            // A custom module map exposing only PVAzaharCoreBridge.h: the other headers pull in azahar's C++.
            publicHeadersPath: "SwiftPM/PVAzaharBridge",
            cSettings: defines.map { CSetting.define($0, to: "1") } + (bridgeCFlags.isEmpty ? [] : [.unsafeFlags(bridgeCFlags)]),
            cxxSettings: defines.map { CXXSetting.define($0, to: "1") } + [.unsafeFlags(bridgeCXXFlags)],
            linkerSettings: systemLinks + [.unsafeFlags(linkerFlags)]
        ),
    ] + (libraryPresent ? [
        // MARK: Emulator (prebuilt, arm64 only)

        .binaryTarget(name: "PVlibAzahar", path: xcframework),
    ] : []),
    swiftLanguageModes: [.v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
