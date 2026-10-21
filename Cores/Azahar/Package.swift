// swift-tools-version:6.0

import Foundation
import PackageDescription

// Shipping Xcode and Tuist both consume PVAzahar-Dynamic.
// Run `make prepare-azahar AZAHAR_SLICE=ios` (or ios-sim/tvos/tvos-sim) before resolving.
// The engine remains a cached CMake-built XCFramework; the Swift/ObjC++ APIs are source targets.
// All slices are arm64. Header ordering and C++ symbol isolation are required for coexistence
// with the other native cores (upstream network/network.h collides with Apple's Network headers).

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let xcframework = "build/xcframework/PVlibAzahar.xcframework"

let azaharHeaders = "\(packageDir)/build/headers"

/// GCC_PREPROCESSOR_DEFINITIONS of the xcodeproj, each defined to 1.
let defines: [String] = [
    "ENABLE_VULKAN",
    "HAVE_COREAUDIO",
    "HAVE_FASTINTERP",
    "VK_NO_PROTOTYPES",
    "VULKAN_HPP_DISPATCH_LOADER_DYNAMIC",
    "VULKAN_HPP_NO_EXCEPTIONS",
]

/// azahar headers are searched last: azahar's network/network.h would otherwise satisfy the SDK's
/// <Network/Network.h> on a case-insensitive volume. Only its network/ dir goes on -I (included as
/// "network.h"). Never include azahar's core/hle/service/nwm/nwm_uds.h (see CLAUDE.md).
let headerFlags: [String] = ["-idirafter", azaharHeaders, "-I", "\(azaharHeaders)/network"]

let bridgeCFlags: [String] = headerFlags
let bridgeCXXFlags: [String] = [
    "-fmodules",
    "-fcxx-modules",   // the ObjC++ glue does @import PVCoreBridge
    "-Wno-shorten-64-to-32",
    "-Wno-deprecated-declarations",
] + headerFlags

/// Hide C++ symbols at the final image link: Xcode localizes hidden definitions while combining SwiftPM
/// bridge objects, before Swift and the engine can resolve them. dyld coalesces exported weak definitions across images,
/// and PVlibDolphin's glslang/fmt instantiations crashed azahar's shader compiler (unexported_symbols.txt).
let linkerFlags: [String] = [
    "-Xlinker", "-ObjC",
    "-Xlinker", "-unexported_symbols_list",
    "-Xlinker", "\(packageDir)/unexported_symbols.txt",
]

/// Paths every target leaves out; each target then lists only its own files in `sources`.
let sharedExcludes: [String] = [
    "azahar",
    "cmake",
    "Tests",
    "PVAzahar/Info.plist",
    "PVAzahar/PVAzahar.h",
    "PATCHES.md",
    "build_azahar_core.py",
    "swiftgen.yml",
    "unexported_symbols.txt",
    "build", // prepared native output
]

let swiftSources: [String] = [
    "PVAzaharCore/CorePlist.swift",
    "PVAzaharCore/CorePlist-Generated.swift",
    "PVAzaharCore/PVAzaharCore.swift",
    "PVAzaharCore/PVAzaharCoreOptions.swift",
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

// Targets and their settings are typed constants: one `Package(...)` literal with inline
// `map`/`+` expressions made the manifest type-check time out on CI.

let coreDependencies: [Target.Dependency] = [
    "PVAzaharSupport",
    .product(name: "Defaults", package: "Defaults"),
    "PVAzaharBridge",
    .product(name: "PVCoreBridge", package: "PVCoreBridge"),
    .product(name: "PVCoreObjCBridge", package: "PVCoreObjCBridge"),
    .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
    .product(name: "PVLogging", package: "PVLogging"),
    .product(name: "PVPlists", package: "PVPlists"),
    .product(name: "PVPrimitives", package: "PVPrimitives"),
    .product(name: "PVSettings", package: "PVSettings"),
    .product(name: "PVSupport", package: "PVSupport"),
]
let coreExcludes: [String] = sharedExcludes + bridgeSources + bridgeHeaders + ["SwiftPM", "Sources", "PVAzaharCore/PVAzaharDataMigrator.swift"]

// MARK: Core (Swift)
let coreTarget: Target = .target(
    name: "PVAzahar",
    dependencies: coreDependencies,
    path: ".",
    exclude: coreExcludes,
    sources: swiftSources,
    resources: [
        .process("PVAzahar/Core.plist"),
    ],
    swiftSettings: [
        .interoperabilityMode(.Cxx),   // SWIFT_OBJC_INTEROP_MODE = objcxx in the xcodeproj
    ]
)

var bridgeDependencies: [Target.Dependency] = [
    .product(name: "PVAudio", package: "PVAudio"),
    .product(name: "PVCoreBridge", package: "PVCoreBridge"),
    .product(name: "PVCoreObjCBridge", package: "PVCoreObjCBridge"),
    .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
    .product(name: "PVJIT", package: "PVJIT"),
    .product(name: "PVLogging", package: "PVLogging"),
    .product(name: "PVObjCUtils", package: "PVObjCUtils"),
    .product(name: "PVSupport", package: "PVSupport"),
]
bridgeDependencies.append("PVlibAzahar")

let bridgeExcludes: [String] = sharedExcludes + swiftSources + ["PVAzahar/Core.plist", "Sources", "PVAzaharCore/PVAzaharDataMigrator.swift"]
let bridgeSourceList: [String] = bridgeSources + bridgeHeaders

var bridgeCSettings: [CSetting] = defines.map { CSetting.define($0, to: "1") }
if !bridgeCFlags.isEmpty { bridgeCSettings.append(.unsafeFlags(bridgeCFlags)) }
var bridgeCXXSettings: [CXXSetting] = defines.map { CXXSetting.define($0, to: "1") }
bridgeCXXSettings.append(.unsafeFlags(bridgeCXXFlags))
var bridgeLinkerSettings: [LinkerSetting] = systemLinks
bridgeLinkerSettings.append(.unsafeFlags(linkerFlags))

// MARK: Bridge (ObjC++)
let bridgeTarget: Target = .target(
    name: "PVAzaharBridge",
    dependencies: bridgeDependencies,
    path: ".",
    exclude: bridgeExcludes,
    sources: bridgeSourceList,
    // A custom module map exposing only PVAzaharCoreBridge.h: the other headers pull in azahar's C++.
    publicHeadersPath: "SwiftPM/PVAzaharBridge",
    cSettings: bridgeCSettings,
    cxxSettings: bridgeCXXSettings,
    linkerSettings: bridgeLinkerSettings
)

let allTargets: [Target] = [
    coreTarget,
    bridgeTarget,
    .binaryTarget(name: "PVlibAzahar", path: xcframework),
    .target(name: "PVAzaharSupport", dependencies: ["PVLogging"]),
    .testTarget(name: "PVAzaharDataMigratorTests", dependencies: ["PVAzaharSupport"], path: "Tests"),
]

let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2"),
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
    dependencies: packageDependencies,
    targets: allTargets,
    swiftLanguageModes: [.v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
