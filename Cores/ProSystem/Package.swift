// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVCoreProSystem",
    platforms: [
        .iOS(.v17),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVProSystem",
            targets: ["PVProSystem"]),
        .library(
            name: "PVProSystem-Dynamic",
            type: .dynamic,
            targets: ["PVProSystem"]),
        .library(
            name: "PVProSystem-Static",
            type: .static,
            targets: ["PVProSystem"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVObjCUtils"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        
        // MARK: ------- Core -------

        .target(
            name: "PVProSystem",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVPlists",
                "PVProSystemBridge",
                "libprosystem",
            ],
            resources: [
                .process("Resources/Core.plist"),
                .copy("Resources/ProSystem.dat")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),

        
        // MARK: ------- Bridge -------
        
        .target(
            name: "PVProSystemBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVObjCUtils",
                "libprosystem",
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ])
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        
        // MARK: ------- Core -------

    
        .target(
            name: "libprosystem",
            sources: Sources.libprosystem,
            packageAccess: true,
            cSettings: [
                .headerSearchPath("ProSystem/core"),
                .headerSearchPath("ProSystem/core/lib"),
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx17
)

enum Sources {
    static let libprosystem: [String] = [
        "ProSystem/core/Archive.cpp",
        "ProSystem/core/Bios.cpp",
        "ProSystem/core/Cartridge.cpp",
        "ProSystem/core/Common.cpp",
        "ProSystem/core/Database.cpp",
        "ProSystem/core/Hash.cpp",
        "ProSystem/core/Logger.cpp",
        "ProSystem/core/Maria.cpp",
        "ProSystem/core/Memory.cpp",
        "ProSystem/core/Palette.cpp",
        "ProSystem/core/Pokey.cpp",
        "ProSystem/core/ProSystem.cpp",
        "ProSystem/core/Region.cpp",
        "ProSystem/core/Riot.cpp",
        "ProSystem/core/Sally.cpp",
        "ProSystem/core/Sound.cpp",
        "ProSystem/core/Tia.cpp",
        "ProSystem/core/Timer.cpp",
        "ProSystem/core/lib/Unzip.c",
        "ProSystem/core/lib/Zip.c",
    ]
    
    static let libprosystem_1_3: [String] = [
        "ProSystem1_3/Core/Archive.cpp",
        "ProSystem1_3/Core/Bios.cpp",
        "ProSystem1_3/Core/Cartridge.cpp",
        "ProSystem1_3/Core/Common.cpp",
        "ProSystem1_3/Core/Hash.cpp",
        "ProSystem1_3/Core/Logger.cpp",
        "ProSystem1_3/Core/Maria.cpp",
        "ProSystem1_3/Core/Memory.cpp",
        "ProSystem1_3/Core/Palette.cpp",
        "ProSystem1_3/Core/Pokey.cpp",
        "ProSystem1_3/Core/ProSystem.cpp",
        "ProSystem1_3/Core/Region.cpp",
        "ProSystem1_3/Core/Riot.cpp",
        "ProSystem1_3/Core/Sally.cpp",
        "ProSystem1_3/Core/Sound.cpp",
        "ProSystem1_3/Core/Tia.cpp",
        "ProSystem1_3/Core/lib/Unzip.c",
        "ProSystem1_3/Core/lib/Zip.c",
    ]
}
