// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Stella core sources: the SOURCES_CXX list of
/// stella/src/os/libretro/Makefile.common, relative to Sources/libstella.
let stellaCoreSources: [String] = [
    "stella/src/os/libretro/libretro.cxx",
    "stella/src/os/libretro/FSNodeLIBRETRO.cxx",
    "stella/src/os/libretro/StellaLIBRETRO.cxx",
    "stella/src/common/AudioQueue.cxx",
    "stella/src/common/AudioSettings.cxx",
    "stella/src/common/Base.cxx",
    "stella/src/common/Bezel.cxx",
    "stella/src/common/DevSettingsHandler.cxx",
    "stella/src/common/FpsMeter.cxx",
    "stella/src/common/FSNodeZIP.cxx",
    "stella/src/common/JoyMap.cxx",
    "stella/src/common/KeyMap.cxx",
    "stella/src/common/Logger.cxx",
    "stella/src/common/MouseControl.cxx",
    "stella/src/common/PaletteHandler.cxx",
    "stella/src/common/PhosphorHandler.cxx",
    "stella/src/common/PhysicalJoystick.cxx",
    "stella/src/common/PJoystickHandler.cxx",
    "stella/src/common/PKeyboardHandler.cxx",
    "stella/src/common/RewindManager.cxx",
    "stella/src/common/StaggeredLogger.cxx",
    "stella/src/common/StateManager.cxx",
    "stella/src/common/TimerManager.cxx",
    "stella/src/common/VideoModeHandler.cxx",
    "stella/src/common/tv_filters/AtariNTSC.cxx",
    "stella/src/common/tv_filters/NTSCFilter.cxx",
    "stella/src/common/repository/CompositeKeyValueRepository.cxx",
    "stella/src/common/repository/CompositeKVRJsonAdapter.cxx",
    "stella/src/common/repository/KeyValueRepositoryConfigfile.cxx",
    "stella/src/common/repository/KeyValueRepositoryJsonFile.cxx",
    "stella/src/common/repository/KeyValueRepositoryPropertyFile.cxx",
    "stella/src/emucore/AtariVox.cxx",
    "stella/src/emucore/Booster.cxx",
    "stella/src/emucore/Cart.cxx",
    "stella/src/emucore/CartCreator.cxx",
    "stella/src/emucore/CartDetector.cxx",
    "stella/src/emucore/CartEnhanced.cxx",
    "stella/src/emucore/Cart03E0.cxx",
    "stella/src/emucore/Cart0840.cxx",
    "stella/src/emucore/Cart0FA0.cxx",
    "stella/src/emucore/Cart2K.cxx",
    "stella/src/emucore/Cart3E.cxx",
    "stella/src/emucore/Cart3EPlus.cxx",
    "stella/src/emucore/Cart3EX.cxx",
    "stella/src/emucore/Cart3F.cxx",
    "stella/src/emucore/Cart4A50.cxx",
    "stella/src/emucore/Cart4K.cxx",
    "stella/src/emucore/Cart4KSC.cxx",
    "stella/src/emucore/CartAR.cxx",
    "stella/src/emucore/CartARM.cxx",
    "stella/src/emucore/CartBF.cxx",
    "stella/src/emucore/CartBFSC.cxx",
    "stella/src/emucore/CartBUS.cxx",
    "stella/src/emucore/CartCDF.cxx",
    "stella/src/emucore/CartCM.cxx",
    "stella/src/emucore/CartCTY.cxx",
    "stella/src/emucore/CartCV.cxx",
    "stella/src/emucore/CartDevCard.cxx",
    "stella/src/emucore/CartDF.cxx",
    "stella/src/emucore/CartDFSC.cxx",
    "stella/src/emucore/CartDPC.cxx",
    "stella/src/emucore/CartDPCPlus.cxx",
    "stella/src/emucore/CartE0.cxx",
    "stella/src/emucore/CartE7.cxx",
    "stella/src/emucore/CartEF.cxx",
    "stella/src/emucore/CartEFF.cxx",
    "stella/src/emucore/CartEFSC.cxx",
    "stella/src/emucore/CartELF.cxx",
    "stella/src/emucore/CartF0.cxx",
    "stella/src/emucore/CartF4.cxx",
    "stella/src/emucore/CartF4SC.cxx",
    "stella/src/emucore/CartF6.cxx",
    "stella/src/emucore/CartF6SC.cxx",
    "stella/src/emucore/CartF8.cxx",
    "stella/src/emucore/CartF8SC.cxx",
    "stella/src/emucore/CartFA2.cxx",
    "stella/src/emucore/CartFA.cxx",
    "stella/src/emucore/CartFC.cxx",
    "stella/src/emucore/CartFE.cxx",
    "stella/src/emucore/CartGL.cxx",
    "stella/src/emucore/CartJANE.cxx",
    "stella/src/emucore/CartMDM.cxx",
    "stella/src/emucore/CartMVC.cxx",
    "stella/src/emucore/CartSB.cxx",
    "stella/src/emucore/CartTVBoy.cxx",
    "stella/src/emucore/CartUA.cxx",
    "stella/src/emucore/CartWD.cxx",
    "stella/src/emucore/CartWF8.cxx",
    "stella/src/emucore/CartX07.cxx",
    "stella/src/emucore/CompuMate.cxx",
    "stella/src/emucore/CompuMateCassette.cxx",
    "stella/src/emucore/Console.cxx",
    "stella/src/emucore/Control.cxx",
    "stella/src/emucore/ControllerDetector.cxx",
    "stella/src/emucore/CortexM0.cxx",
    "stella/src/emucore/DispatchResult.cxx",
    "stella/src/emucore/Driving.cxx",
    "stella/src/emucore/EmulationTiming.cxx",
    "stella/src/emucore/EmulationWorker.cxx",
    "stella/src/emucore/EventHandler.cxx",
    "stella/src/emucore/FBSurface.cxx",
    "stella/src/emucore/FrameBuffer.cxx",
    "stella/src/emucore/FBMessageHandler.cxx",
    "stella/src/emucore/FSNode.cxx",
    "stella/src/emucore/Genesis.cxx",
    "stella/src/emucore/GlobalKeyHandler.cxx",
    "stella/src/emucore/Joy2BPlus.cxx",
    "stella/src/emucore/Joystick.cxx",
    "stella/src/emucore/Keyboard.cxx",
    "stella/src/emucore/KidVid.cxx",
    "stella/src/emucore/Lightgun.cxx",
    "stella/src/emucore/M6502.cxx",
    "stella/src/emucore/M6532.cxx",
    "stella/src/emucore/MD5.cxx",
    "stella/src/emucore/MindLink.cxx",
    "stella/src/emucore/OSystem.cxx",
    "stella/src/emucore/Paddles.cxx",
    "stella/src/emucore/PlusROM.cxx",
    "stella/src/emucore/PointingDevice.cxx",
    "stella/src/emucore/Props.cxx",
    "stella/src/emucore/PropsSet.cxx",
    "stella/src/emucore/QuadTari.cxx",
    "stella/src/emucore/SaveKey.cxx",
    "stella/src/emucore/Serializer.cxx",
    "stella/src/emucore/Settings.cxx",
    "stella/src/emucore/Switches.cxx",
    "stella/src/emucore/System.cxx",
    "stella/src/emucore/Thumbulator.cxx",
    "stella/src/emucore/elf/BusTransactionQueue.cxx",
    "stella/src/emucore/elf/ElfEnvironment.cxx",
    "stella/src/emucore/elf/ElfLinker.cxx",
    "stella/src/emucore/elf/ElfParser.cxx",
    "stella/src/emucore/elf/ElfUtil.cxx",
    "stella/src/emucore/elf/VcsLib.cxx",
    "stella/src/emucore/tia/AudioChannel.cxx",
    "stella/src/emucore/tia/Audio.cxx",
    "stella/src/emucore/tia/Background.cxx",
    "stella/src/emucore/tia/Ball.cxx",
    "stella/src/emucore/tia/DrawCounterDecodes.cxx",
    "stella/src/emucore/tia/frame-manager/AbstractFrameManager.cxx",
    "stella/src/emucore/tia/frame-manager/FrameLayoutDetector.cxx",
    "stella/src/emucore/tia/frame-manager/FrameManager.cxx",
    "stella/src/emucore/tia/frame-manager/JitterEmulation.cxx",
    "stella/src/emucore/tia/LatchedInput.cxx",
    "stella/src/emucore/tia/Missile.cxx",
    "stella/src/emucore/tia/AnalogReadout.cxx",
    "stella/src/emucore/tia/Player.cxx",
    "stella/src/emucore/tia/Playfield.cxx",
    "stella/src/emucore/TIASurface.cxx",
    "stella/src/emucore/tia/TIA.cxx",
]

let package = Package(
    name: "PVCoreStella",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVStella",
            targets: ["PVStella"]),
        .library(
            name: "PVStella-Dynamic",
            type: .dynamic,
            targets: ["PVStella"]),
        .library(
            name: "PVStella-Static",
            type: .static,
            targets: ["PVStella"]),
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
        .package(name: "PVNetplay", path: "../../PVNetplay"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),
    ],
    targets: [
        // MARK: ------- Core ---------

        .target(
            name: "PVStella",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVPrimitives",
                "libstella",
                "PVStellaCPP",
                "PVStellaBridge",
                .product(name: "PVRcheevos", package: "PVRcheevos"),
                .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            plugins: [
                // Disabled until SwiftGenPlugin support Swift 6 concurrency
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),

        // MARK: ------- Bridge ---------

        .target(
            name: "PVStellaBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVPlists",
                "PVObjCUtils",
                "PVStellaCPP",
                "libstella",
                .product(name: "CRcheevos", package: "PVRcheevos"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("HAVE_RCHEEVOS", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ]),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("HAVE_RCHEEVOS", to: "1"),
                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libstella/stella/src/os/libretro/"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        
        // MARK: ------- CPP Helper ---------

        .target(
            name: "PVStellaCPP",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libstella",
            ],
            publicHeadersPath: "./",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ])
            ]
        ),
        
        // MARK: ------- Emulator ---------

        // Stella's emulation core, compiled from the Provenance-Emu/stella
        // submodule (branch Provenance-master, tracking stella-emu master).
        // The file list, include paths and defines mirror upstream's libretro
        // build (stella/src/os/libretro/Makefile.common and Makefile), so the
        // SDL/Qt GUI, debugger and cheat dialogs are never compiled. When
        // bumping the submodule, re-sync `stellaCoreSources` with that file.
        .target(
            name: "libstella",
            // Only `sources` is compiled; these are excluded so SwiftPM does not
            // pick up the desktop frontends' .lproj/.xcodeproj as resources.
            exclude: [
                "stella/debian",
                "stella/docs",
                "stella/test",
                "stella/src/debugger",
                "stella/src/gui",
                "stella/src/tools",
                "stella/src/os/macos",
                "stella/src/os/unix",
                "stella/src/os/windows",
                "stella/src/os/libretro/jni",
            ],
            sources: stellaCoreSources,
            publicHeadersPath: "include",
            packageAccess: true,
            cxxSettings: [
                .define("__LIB_RETRO__"),
                .define("SOUND_SUPPORT"),
                .define("HAVE_STDINT_H"),
                .headerSearchPath("stella/src"),
                .headerSearchPath("stella/src/os/libretro"),
                .headerSearchPath("stella/src/emucore"),
                .headerSearchPath("stella/src/emucore/elf"),
                .headerSearchPath("stella/src/emucore/tia"),
                .headerSearchPath("stella/src/common"),
                .headerSearchPath("stella/src/common/audio"),
                .headerSearchPath("stella/src/common/tv_filters"),
                .headerSearchPath("stella/src/common/repository/sqlite"),
                .headerSearchPath("stella/src/lib"),
                .headerSearchPath("stella/src/lib/sqlite"),
                .unsafeFlags([
                    // Upstream needs C++23 (#elifdef, `using enum`). Kept local to
                    // this target: the bridge only sees the C libretro.h API, so it
                    // and the Swift interop stay on the package-wide standard.
                    "-std=gnu++23",
                    // Debug builds define DEBUG=1, which collides with the
                    // `Logger::Level::DEBUG` enumerator in common/Logger.hxx.
                    "-UDEBUG",
                    "-fno-rtti",
                ])
            ]
        ),

        // MARK: ------- Tests ---------

        .testTarget(
            name: "PVStellaTests",
            dependencies: ["PVStella"],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)
