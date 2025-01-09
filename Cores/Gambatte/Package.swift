// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVCoreGambatte",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVGambatte",
            targets: ["PVGambatte"]),
        .library(
            name: "PVGambatte-Dynamic",
            type: .dynamic,
            targets: ["PVGambatte"]),
        .library(
            name: "PVGambatte-Static",
            type: .static,
            targets: ["PVGambatte"]),
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
        // MARK: ------- CORE --------
        .target(
            name: "PVGambatte",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVPlists",
                "PVGambatteBridge",
                "PVGambatteOptions",
                "libgambatte",
                "libresample"
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
            ],
            cxxSettings: [
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        // MARK: ------- Bridge --------
        .target(
            name: "PVGambatteBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVGambatteOptions",
                "libgambatte",
                "libresample"
            ],
            cSettings: [
                .define("INT_LEAST_32"),
                .define("HAVE_STDINT_H", to: "1"),
                .headerSearchPath("../libgambatte/libgambatte/include"),
                .headerSearchPath("../libresample/common/resample"),
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ])
            ],
            cxxSettings: [
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        // MARK: ------- Options --------
        .target(
            name: "PVGambatteOptions",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libgambatte",
                "libresample"
            ],
            cSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ])
            ],
            cxxSettings: [
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        // MARK: ------- gambatte --------
        .target(
            name: "libgambatte",
            dependencies: [
                "libresample"
            ],
            sources: Sources.gambatte,
            packageAccess: true,
            cSettings: [
                .define("INT_LEAST_32"),
                .define("HAVE_STDINT_H", to: "1"),
                .headerSearchPath("libgambatte/include"),
                .headerSearchPath("libgambatte/src"),
                .headerSearchPath("libgambatte/src/file"),
                .headerSearchPath("libgambatte/src/men"),
                .headerSearchPath("libgambatte/src/sound"),
                .headerSearchPath("libgambatte/src/video"),
                .headerSearchPath("../libresample/common"),
                .headerSearchPath("../libresample/common/resample")
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fno-exceptions",
                    "-fno-rtti"
                ])
            ]
        ),
        // MARK: ------- resample --------
        .target(
            name: "libresample",
            sources: Sources.resample,
            packageAccess: true,
            cSettings: [
                .define("HAVE_STDINT_H", to: "1"),
                .headerSearchPath("common/"),
                .headerSearchPath("common/resample"),
                .headerSearchPath("common/resample/src")
            ],
            cxxSettings: [
            ],
            linkerSettings: [
                .unsafeFlags(["-lc++"])
            ]
        ),
        // MARK: ------- Tests -------
        .testTarget(
            name: "PVGambaTests",
            dependencies: [
                "PVGambatte",
                "PVGambatteBridge",
                "PVCoreBridge",
                "PVEmulatorCore",
                "libgambatte",
                "libresample"
            ],
            resources: [],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .c99,
    cxxLanguageStandard: .gnucxx11
)

enum Sources {
    static let resample: [String] = [
        "common/resample/src/chainresampler.cpp",
        "common/resample/src/i0.cpp",
        "common/resample/src/kaiser50sinc.cpp",
        "common/resample/src/kaiser70sinc.cpp",
        "common/resample/src/makesinckernel.cpp",
        "common/resample/src/resamplerinfo.cpp",
        "common/resample/src/u48div.cpp"
    ]
    
    static let gambatte: [String] = [
        "libgambatte/src/bitmap_font.cpp",
        "libgambatte/src/cpu.cpp",
        "libgambatte/src/file/file.cpp",
        "libgambatte/src/gambatte.cpp",
        "libgambatte/src/initstate.cpp",
        "libgambatte/src/interrupter.cpp",
        "libgambatte/src/interruptrequester.cpp",
        "libgambatte/src/loadres.cpp",
        "libgambatte/src/mem/cartridge.cpp",
        "libgambatte/src/mem/memptrs.cpp",
        "libgambatte/src/mem/pakinfo.cpp",
        "libgambatte/src/mem/rtc.cpp",
        "libgambatte/src/memory.cpp",
        "libgambatte/src/sound.cpp",
        "libgambatte/src/sound/channel1.cpp",
        "libgambatte/src/sound/channel2.cpp",
        "libgambatte/src/sound/channel3.cpp",
        "libgambatte/src/sound/channel4.cpp",
        "libgambatte/src/sound/duty_unit.cpp",
        "libgambatte/src/sound/envelope_unit.cpp",
        "libgambatte/src/sound/length_counter.cpp",
        "libgambatte/src/state_osd_elements.cpp",
        "libgambatte/src/statesaver.cpp",
        "libgambatte/src/tima.cpp",
        "libgambatte/src/video.cpp",
        "libgambatte/src/video/ly_counter.cpp",
        "libgambatte/src/video/lyc_irq.cpp",
        "libgambatte/src/video/next_m0_time.cpp",
        "libgambatte/src/video/ppu.cpp",
        "libgambatte/src/video/sprite_mapper.cpp"
    ]
}

/*
 
 PVGB files:

 common/resample/src/chainresampler.cpp
 common/resample/src/i0.cpp
 common/resample/src/kaiser50sinc.cpp
 common/resample/src/kaiser70sinc.cpp
 common/resample/src/makesinckernel.cpp
 common/resample/src/resamplerinfo.cpp
 common/resample/src/u48div.cpp
 
 libgambatte/src/bitmap_font.cpp
 libgambatte/src/cpu.cpp
 libgambatte/src/file/file.cpp
 libgambatte/src/gambatte.cpp
 libgambatte/src/initstate.cpp
 libgambatte/src/interrupter.cpp
 libgambatte/src/interruptrequester.cpp
 libgambatte/src/loadres.cpp
 libgambatte/src/mem/cartridge.cpp
 libgambatte/src/mem/memptrs.cpp
 libgambatte/src/mem/pakinfo.cpp
 libgambatte/src/mem/rtc.cpp
 libgambatte/src/memory.cpp
 libgambatte/src/sound.cpp
 libgambatte/src/sound/channel1.cpp
 libgambatte/src/sound/channel2.cpp
 libgambatte/src/sound/channel3.cpp
 libgambatte/src/sound/channel4.cpp
 libgambatte/src/sound/duty_unit.cpp
 libgambatte/src/sound/envelope_unit.cpp
 libgambatte/src/sound/length_counter.cpp
 libgambatte/src/state_osd_elements.cpp
 libgambatte/src/statesaver.cpp
 libgambatte/src/tima.cpp
 libgambatte/src/video.cpp
 libgambatte/src/video/ly_counter.cpp
 libgambatte/src/video/lyc_irq.cpp
 libgambatte/src/video/next_m0_time.cpp
 libgambatte/src/video/ppu.cpp
 libgambatte/src/video/sprite_mapper.cpp


 */
