// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let sharedCSettings: [CSetting] = [
    .define("__unix__"),
    .define("GCC"),
    
    .define("GLES_SILENCE_DEPRECATION", to: "1"),
    .define("GL_SILENCE_DEPRECATION", to: "1"),
    .define("M64P_PLUGIN_PROTOTYPES", to: "1"),
    .define("MUPENPLUSAPI", to: "1"),
    .define("M64P_PLUGIN_API", to: "1"),
    
    .define("IN_OPENEMU", to: "1"),
//    .define("M64P_CORE_PROTOTYPES", to: "1"),
    .define("PIC", to: "1"),

//    .define("NDEBUG", to: "1", .when(configuration: [.release])),
//    .define("DEBUG", to: "1", .when(configuration: [.debug])),
 
    .define("M64P_PARALLEL", to: "1"),

    .define("NO_ASM", to: "1"),
    .define("PROVENANCE", to: "1"),
    .define("TXFILTER_LIB", to: "1"),
    .define("VALIDATE_WORKSPACE_SKIPPED_SDK_FRAMEWORKS", to: "OpenGLES"),
    .define("VFP_HARD", to: "1"),
    
    .define("GLESX", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("OS_IOS", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("__VEC4_OPT", .when(platforms: [.iOS, .tvOS])),
    // No __NEON_OPT: SwiftPM can't exclude the Neon/*.cpp sources per architecture, and the
    // x86_64 simulator slice can't compile them. The package uses GlideN64's generic C++ paths
    // (the shipping xcodeproj keeps NEON).
    .define("SDL_VIDEO_OPENGL_ES2", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES2", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES3", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES3_2", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES_ES2", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES_ES3", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("USE_GLES_ES3_2", to: "1", .when(platforms: [.iOS, .tvOS])),
    
    .define("OS_MAC_OS_X", to: "1", .when(platforms: [.macOS, .macCatalyst])),
    .define("SDL_VIDEO_OPENGL", to: "", .when(platforms: [.macOS, .macCatalyst])),
    
    // (EXCLUDED_SOURCE_FILE_NAMES is an Xcode build setting, not a preprocessor define; the Neon
    // sources are simply not listed below.)
]

let sharedSwiftSettings: [SwiftSetting] = [
    .define("GLES_SILENCE_DEPRECATION"),
    .define("GL_SILENCE_DEPRECATION"),
    .define("M64P_PLUGIN_PROTOTYPES"),
    .define("MUPENPLUSAPI"),
    .define("NO_ASM"),
    .define("PROVENANCE"),
    .define("TXFILTER_LIB"),
    .define("USE_GLES", .when(platforms: [.iOS, .tvOS])),
    .define("VFP_HARD"),
    .define("__unix__")
]

let packagePlatforms: [SupportedPlatform] = [
    .iOS(.v17),
    .tvOS(.v17),
    .macOS(.v13),
    .macCatalyst(.v17),
    .visionOS(.v1)
]

let packageProducts: [Product] = [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
        name: "PVMupenGameCore",
        targets: ["PVMupen"]),
    .library(
        name: "PVMupenGameCore-Dynamic",
        type: .dynamic,
        targets: ["PVMupen"]),
    .library(
        name: "PVMupenGameCore-Static",
        type: .static,
        targets: ["PVMupen"]),

    // Plugins the core dlopens at runtime (PVMupenBridge.m `LoadPlugin`). Each is its own
    // dynamic framework, embedded next to the core. They are NOT linked into PVMupen:
    // linking one statically would duplicate its PluginStartup/PluginShutdown exports.
    // PVMupenBridge and PVMupen64PlusCore are static members of PVMupenGameCore-Dynamic
    // (the old PVMupen64PlusBridge framework), so they get no product of their own.
    .library(
        name: "PVMupen64PlusRspHLE-Dynamic",
        type: .dynamic,
        targets: ["PVMupen64PlusRspHLE"]),
    .library(
        name: "PVRSPCXD4-Dynamic",
        type: .dynamic,
        targets: ["PVRSPCXD4"]),
    .library(
        name: "PVMupen64PlusVideoRice-Dynamic",
        type: .dynamic,
        targets: ["PVMupen64PlusVideoRice"]),
    .library(
        name: "PVMupen64PlusVideoGlideN64-Dynamic",
        type: .dynamic,
        targets: ["PVMupen64PlusVideoGlideN64"]),
]

let packageDependencies: [Package.Dependency] = [
    .package(path: "../../PVCoreBridge"),
    .package(path: "../../PVCoreObjCBridge"),
    .package(path: "../../PVPlists"),
    .package(path: "../../PVEmulatorCore"),
    .package(path: "../../PVSupport"),
    .package(path: "../../PVAudio"),
    .package(path: "../../PVLogging"),
    .package(path: "../../PVObjCUtils"),
    .package(name: "PVPrimitives", path: "../../PVPrimitives/"),
    .package(path: "../../PVSettings"),
    .package(path: "../../PVNetplay"),
    .package(path: "../../PVRcheevos"),
    .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),

    .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),
]


// MARK: ------- CORE -------- //

let pvMupenDeps: [Target.Dependency] = [
    "PVAudio",
    "PVCoreBridge",
    "PVCoreObjCBridge",
    "PVEmulatorCore",
    "PVLogging",
    "PVPlists",
    "PVPrimitives",   // SystemIdentifier; a dynamic product links only what its target declares
    "PVSettings",     // imported by MupenGameCore (+ Defaults through it)
    "PVSupport",
    "PVMupenBridge",
    "PVMupen64PlusCore",
    .product(name: "CRcheevos", package: "PVRcheevos"),
    .product(name: "PVRcheevos", package: "PVRcheevos"),
    .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
    .product(name: "PVNetplay", package: "PVNetplay",
             condition: .when(platforms: [.iOS, .tvOS, .macOS, .macCatalyst, .visionOS])),
]

let pvMupenResources: [Resource] = [
    .process("Resources/Core.plist")
]

let pvMupenExtraCSettings: [CSetting] = [
    .headerSearchPath("../Plugins/Core/Core/src/"),
]
let pvMupenCSettings: [CSetting] = pvMupenExtraCSettings + sharedCSettings

let pvMupenPlugins: [Target.PluginUsage] = [] // CorePlist-Generated.swift is committed; the SwiftGen plugin would try to rewrite it in the source tree

let pvMupenTarget: Target = .target(
    name: "PVMupen",
    dependencies: pvMupenDeps,
    resources: pvMupenResources,
    cSettings: pvMupenCSettings,
    swiftSettings: sharedSwiftSettings,
    plugins: pvMupenPlugins
)

// MARK: ------- Bridge -------- //

let pvMupenBridgeDeps: [Target.Dependency] = [
    "PVAudio",
    "PVCoreBridge",
    "PVCoreObjCBridge",
    "PVEmulatorCore",
    "PVLogging",
    "PVObjCUtils",
    "PVPlists",
    "PVSupport",
    "PVMupen64PlusCore",
//                "PVMupen64PlusRspHLE",
//                "PVMupen64PlusVideoGlideN64",
//                "PVMupen64PlusVideoRice",
//                "PVRSPCXD4",
    "SDL"
]

    
    
let pvMupenBridgeExtraCSettings: [CSetting] = [
    .headerSearchPath("../Plugins/Core/Core/src/"),
    .headerSearchPath("../Plugins/Core/Core/src/api"),
    .headerSearchPath("../Plugins/Core/Core/subprojects/md5/"),
    // m64p_frontend.h only declares CoreDoCommand & co. as prototypes with this set
    // (the xcodeproj sets it in its build settings).
    .define("M64P_CORE_PROTOTYPES", to: "1"),
    .headerSearchPath("../Plugins/Core/Core/subprojects/xxhash/"),
]
let pvMupenBridgeCSettings: [CSetting] = sharedCSettings + pvMupenBridgeExtraCSettings

let pvMupenBridgeTarget: Target = .target(
    name: "PVMupenBridge",
    dependencies: pvMupenBridgeDeps,
    cSettings: pvMupenBridgeCSettings
)

    
// MARK: PVMupen64PlusCore

let pvMupen64PlusCoreDeps: [Target.Dependency] = [
    "SDL"
]

let pvMupen64PlusCoreSourceFiles: [String] = [
    "api/callbacks.c",
    "api/common.c",
    "api/config.c",
    "api/debugger.c",
    "api/frontend.c",
    "asm_defines/asm_defines.c",
    "backends/api/video_capture_backend.c",
    "backends/clock_ctime_plus_delta.c",
    "backends/dummy_video_capture.c",
    "backends/file_storage.c",
    "backends/plugins_compat/audio_plugin_compat.c",
    "backends/plugins_compat/input_plugin_compat.c",
    "device/cart/af_rtc.c",
    "device/cart/cart.c",
    "device/cart/cart_rom.c",
    "device/cart/eeprom.c",
    "device/cart/flashram.c",
    "device/cart/is_viewer.c",
    "device/cart/sram.c",
    "device/controllers/game_controller.c",
    "device/controllers/vru_controller.c",
    "device/controllers/paks/biopak.c",
    "device/controllers/paks/mempak.c",
    "device/controllers/paks/rumblepak.c",
    "device/controllers/paks/transferpak.c",
    "device/dd/dd_controller.c",
    "device/dd/disk.c",
    "device/device.c",
    "device/gb/gb_cart.c",
    "device/gb/m64282fp.c",
    "device/gb/mbc3_rtc.c",
    "device/memory/memory.c",
    "device/pif/bootrom_hle.c",
    "device/pif/cic.c",
    "device/pif/n64_cic_nus_6105.c",
    "device/pif/pif.c",
    "device/r4300/cached_interp.c",
    "device/r4300/cp0.c",
    "device/r4300/cp1.c",
    "device/r4300/cp2.c",
    "device/r4300/idec.c",
    "device/r4300/interrupt.c",
    "device/r4300/pure_interp.c",
    "device/r4300/r4300_core.c",
    "device/r4300/tlb.c",
    "device/rcp/ai/ai_controller.c",
    "device/rcp/mi/mi_controller.c",
    "device/rcp/pi/pi_controller.c",
    "device/rcp/rdp/fb.c",
    "device/rcp/rdp/rdp_core.c",
    "device/rcp/ri/ri_controller.c",
    "device/rcp/rsp/rsp_core.c",
    "device/rcp/si/si_controller.c",
    "device/rcp/vi/vi_controller.c",
    "device/rdram/rdram.c",
    "main/cheat.c",
    "main/lirc.c",
//                "main/main.c",
    "main/rom.c",
    "main/savestates.c",
    "main/sdl_key_converter.c",
    "main/util.c",
    "main/workqueue.c",
    "osal/dynamiclib_unix.c",
    "osal/files_macos.c",
    "plugin/dummy_audio.c",
    "plugin/dummy_input.c",
    "plugin/dummy_rsp.c",
    "plugin/dummy_video.c",
    "plugin/plugin.c"
].map { "Core/src/\($0)" }
let pvMupen64PlusCoreSubprojectFiles: [String] = [
    "md5/md5.c",
    "minizip/ioapi.c",
    "minizip/unzip.c",
    "minizip/zip.c"
].map { "Core/subprojects/\($0)" }
let pvMupen64PlusCoreSources: [String] = pvMupen64PlusCoreSourceFiles + pvMupen64PlusCoreSubprojectFiles


















let pvMupen64PlusCoreExtraCSettings: [CSetting] = [
    .headerSearchPath("./Core/src/"),
    .headerSearchPath("./Core/subprojects/"),
    .headerSearchPath("./Core/subprojects/md5/"),
    .headerSearchPath("./Core/subprojects/xxhash/"),
    .define("NOCRYPT"),
    .define("NOUNCRYPT"),
]
let pvMupen64PlusCoreCSettings: [CSetting] = pvMupen64PlusCoreExtraCSettings + sharedCSettings

let pvMupen64PlusCoreTarget: Target = .target(
    name: "PVMupen64PlusCore",
    dependencies: pvMupen64PlusCoreDeps,
    path: "Sources/Plugins/Core/",
    sources: pvMupen64PlusCoreSources,
//            publicHeadersPath: "./include/"
    cSettings: pvMupen64PlusCoreCSettings
)

// MARK: - Plugins

// MARK: PVMupen64PlusVideoRice

let videoRiceDeps: [Target.Dependency] = [
    "libpng",
    "SDL"
]

let videoRiceSources: [String] = [
    "Blender.cpp",
    "Combiner.cpp",
    "Config.cpp",
    "ConvertImage.cpp",
    "ConvertImage16.cpp",
    "Debugger.cpp",
    "DeviceBuilder.cpp",
    "FrameBuffer.cpp",
    "GraphicsContext.cpp",
    "OGLCombiner.cpp",
    "OGLExtensions.cpp",
    "OGLGraphicsContext.cpp",
    "OGLRender.cpp",
    "OGLRenderExt.cpp",
    "OGLTexture.cpp",
    "RSP_Parser.cpp",
    "RSP_S2DEX.cpp",
    "Render.cpp",
    "RenderBase.cpp",
    "RenderExt.cpp",
    "RenderTexture.cpp",
    "Texture.cpp",
    "TextureFilters.cpp",
    "TextureFilters_2xsai.cpp",
    "TextureFilters_hq2x.cpp",
    "TextureFilters_hq4x.cpp",
    "TextureManager.cpp",
    "VectorMath.cpp",
    "Video.cpp",
    "liblinux/BMGImage.c",
    "liblinux/BMGUtils.c",
    "liblinux/bmp.c",
    "liblinux/pngrw.c",
    "osal_dynamiclib_unix.c",
    "osal_files_unix.c"
].map { "rice/src/\($0)" }

let videoRiceExtraCSettings: [CSetting] = [
    .headerSearchPath("./"),
    .headerSearchPath("rice/src/"),
    .headerSearchPath("../../Core/Core/src/"),
    .headerSearchPath("../../Core/Core/src/api"),
    .headerSearchPath("../../../Compatibility/SDL/"),
]
let videoRiceCSettings: [CSetting] = videoRiceExtraCSettings + sharedCSettings

let videoRiceLinkerSettings: [LinkerSetting] = [
    .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .visionOS])),
    .linkedFramework("OpenGL", .when(platforms: [.macOS, .macCatalyst])),
    .linkedFramework("Foundation"),
    .linkedLibrary("z")
]

let videoRiceTarget: Target = .target(
    name: "PVMupen64PlusVideoRice",
    dependencies: videoRiceDeps,
    path: "Sources/Plugins/Video/rice/",
    sources: videoRiceSources,
    // Plugins are dlopen'd, not imported: no include/ dir, so the whole target dir is the header root.
    publicHeadersPath: "./",
    cSettings: videoRiceCSettings,
    linkerSettings: videoRiceLinkerSettings
)

// MARK: PVMupen64PlusRspHLE

let rspHLEDeps: [Target.Dependency] = [
]

let rspHLESources: [String] = [
    "alist.c",
    "alist_audio.c",
    "alist_naudio.c",
    "alist_nead.c",
    "audio.c",
    "cicx105.c",
    "hle.c",
    "hvqm.c",
    "jpeg.c",
    "memory.c",
    "mp3.c",
    "musyx.c",
    "osal_dynamiclib_unix.c",
    "plugin.c",
    "re2.c"
]

let rspHLEExtraCSettings: [CSetting] = [
    .headerSearchPath("./"),
    .headerSearchPath("../../../Core/Core/src/api"),
]
let rspHLECSettings: [CSetting] = rspHLEExtraCSettings + sharedCSettings

let rspHLETarget: Target = .target(
    name: "PVMupen64PlusRspHLE",
    dependencies: rspHLEDeps,
    path: "Sources/Plugins/rsp/hle/src/",
    sources: rspHLESources,
    publicHeadersPath: "./",
    cSettings: rspHLECSettings
)
    
// MARK: PVRSPCXD4

let rspCXD4Deps: [Target.Dependency] = [
]

let rspCXD4Sources: [String] = [
    "module.c",
    "osal_dynamiclib_unix.c",
    "su.c",
    "vu/add.c",
    "vu/divide.c",
    "vu/logical.c",
    "vu/multiply.c",
    "vu/select.c",
    "vu/vu.c"
]

let rspCXD4ExtraCSettings: [CSetting] = [
    .headerSearchPath("./"),
    .headerSearchPath("../../Core/Core/src/api"),
    .define("HAVE_STANDARD_INTEGER_TYPES"),
    .define("M64P_PLUGIN_API", to: "1")
]
let rspCXD4CSettings: [CSetting] = rspCXD4ExtraCSettings + sharedCSettings

let rspCXD4Target: Target = .target(
    name: "PVRSPCXD4",
    dependencies: rspCXD4Deps,
    path: "Sources/Plugins/rsp/cxd4",
    sources: rspCXD4Sources,
    publicHeadersPath: "./",
    cSettings: rspCXD4CSettings
)

// MARK: PVMupen64PlusVideoGlideN64

let glideN64Deps: [Target.Dependency] = [
    "CZlib",
    "glidenhq",
    "gliden_osd"
]

let glideN64Sources: [String] = [
    "BufferCopy/ColorBufferToRDRAM.cpp",
    "BufferCopy/DepthBufferToRDRAM.cpp",
    "BufferCopy/RDRAMtoColorBuffer.cpp",
    "Combiner.cpp",
    "CombinerKey.cpp",
    "CommonPluginAPI.cpp",
    "Config.cpp",
    "DebugDump.cpp",
    "Debugger.cpp",
    "DepthBuffer.cpp",
    "DepthBufferRender/ClipPolygon.cpp",
    "DepthBufferRender/DepthBufferRender.cpp",
    "DisplayLoadProgress.cpp",
    "DisplayWindow.cpp",
    "FrameBuffer.cpp",
    "FrameBufferInfo.cpp",
    "GBI.cpp",
    "GLideN64.cpp",
    "Graphics/ColorBufferReader.cpp",
    "Graphics/CombinerProgram.cpp",
    "Graphics/Context.cpp",
    "Graphics/ObjectHandle.cpp",
    "Graphics/OpenGLContext/GLFunctions.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_CombinerInputs.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_CombinerProgramBuilder.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_CombinerProgramImpl.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_CombinerProgramUniformFactory.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_FXAA.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_ShaderStorage.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_SpecialShadersFactory.cpp",
    "Graphics/OpenGLContext/GLSL/glsl_Utils.cpp",
    "Graphics/OpenGLContext/mupen64plus/mupen64plus_DisplayWindow.cpp",
    "Graphics/OpenGLContext/opengl_Attributes.cpp",
    "Graphics/OpenGLContext/opengl_BufferManipulationObjectFactory.cpp",
    "Graphics/OpenGLContext/opengl_BufferedDrawer.cpp",
    "Graphics/OpenGLContext/opengl_CachedFunctions.cpp",
    "Graphics/OpenGLContext/opengl_ColorBufferReaderWithBufferStorage.cpp",
    "Graphics/OpenGLContext/opengl_ColorBufferReaderWithPixelBuffer.cpp",
    "Graphics/OpenGLContext/opengl_ColorBufferReaderWithReadPixels.cpp",
    "Graphics/OpenGLContext/opengl_ContextImpl.cpp",
    "Graphics/OpenGLContext/opengl_GLInfo.cpp",
    "Graphics/OpenGLContext/opengl_Parameters.cpp",
    "Graphics/OpenGLContext/opengl_TextureManipulationObjectFactory.cpp",
    "Graphics/OpenGLContext/opengl_UnbufferedDrawer.cpp",
    "Graphics/OpenGLContext/opengl_Utils.cpp",
    "GraphicsDrawer.cpp",
    "Keys.cpp",
    "Log_ios.mm",
    "MupenPlusPluginAPI.cpp",
    "N64.cpp",
    // TODO: Conditionally include one or the other of these
    // may need to use a new .cpp with a #include pattern?
    "CRC_OPT.cpp",
    "3DMath.cpp",
    "RSP_LoadMatrix.cpp",
    "gSP.cpp",
    "NoiseTexture.cpp",
    "PaletteTexture.cpp",
    "Performance.cpp",
    "PostProcessor.cpp",
    "RDP.cpp",
    "RSP.cpp",
    "SoftwareRender.cpp",
    "TexrectDrawer.cpp",
    "TextureFilterHandler.cpp",
    "Textures.cpp",
    "VI.cpp",
    "ZlutTexture.cpp",
    "common/CommonAPIImpl_common.cpp",
    "convert.cpp",
    "gDP.cpp",
    "mupenplus/CommonAPIImpl_mupenplus.cpp",
    "mupenplus/Config_mupenplus.cpp",
    "mupenplus/MupenPlusAPIImpl.cpp",
    "osal/osal_files_ios.mm",
    "uCodes/F3D.cpp",
    "uCodes/F3DAM.cpp",
    "uCodes/F3DBETA.cpp",
    "uCodes/F3DDKR.cpp",
    "uCodes/F3DEX.cpp",
    "uCodes/F3DEX2.cpp",
    "uCodes/F3DEX2ACCLAIM.cpp",
    "uCodes/F3DEX2CBFD.cpp",
    "uCodes/F3DFLX2.cpp",
    "uCodes/F3DGOLDEN.cpp",
    "uCodes/F3DPD.cpp",
    "uCodes/F3DSETA.cpp",
    "uCodes/F3DTEXA.cpp",
    "uCodes/F3DZEX2.cpp",
    "uCodes/F5Indi_Naboo.cpp",
    "uCodes/F5Rogue.cpp",
    "uCodes/L3D.cpp",
    "uCodes/L3DEX.cpp",
    "uCodes/L3DEX2.cpp",
    "uCodes/S2DEX.cpp",
    "uCodes/S2DEX2.cpp",
    "uCodes/T3DUX.cpp",
    "uCodes/Turbo3D.cpp",
    "uCodes/ZSort.cpp",
    "uCodes/ZSortBOSS.cpp",
    "xxHash/xxhash.c",
]

let glideN64ExtraCSettings: [CSetting] = [
    .headerSearchPath("./"),
    .headerSearchPath("./osal"),
    .headerSearchPath("./inc")
]
let glideN64CSettings: [CSetting] = glideN64ExtraCSettings + sharedCSettings

let glideN64LinkerSettings: [LinkerSetting] = [
    .linkedLibrary("z"),
    // osal_*.mm / Log.cpp use NSFileManager, NSLog and ObjC ARC runtime calls.
    .linkedFramework("Foundation"),
    .linkedLibrary("objc"),
    .linkedFramework("OpenGL", .when(platforms: [.macOS, .macCatalyst])),
    .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS]))
]

let glideN64Target: Target = .target(
    name: "PVMupen64PlusVideoGlideN64",
    dependencies: glideN64Deps,
    path: "Sources/Plugins/Video/gliden64/src",
    sources: glideN64Sources,









        




 
    publicHeadersPath: "./inc",
    cSettings: glideN64CSettings,
    linkerSettings: glideN64LinkerSettings
)
    
// MARK: - Compatibility

// MARK: Gliden OSD

let glidenOSDSources: [String] = [
    "gliden_osd.cpp"
]

let glidenOSDExtraCSettings: [CSetting] = [
    .headerSearchPath("./"),
    .headerSearchPath("../../Plugins/Video/gliden64/src"),
    .headerSearchPath("../../Plugins/Video/rice/src"),
    .headerSearchPath("../../Plugins/Core/Core/src"),
    .unsafeFlags([
        "-ffast-math",
        "-fno-strict-aliasing",
        "-fomit-frame-pointer",
        "-fPIC",
        "-pthread"
    ]),
]
let glidenOSDCSettings: [CSetting] = glidenOSDExtraCSettings + sharedCSettings

let glidenOSDTarget: Target = .target(
    name: "gliden_osd",
    path: "Sources/Compatibility/GlideN/",
    sources: glidenOSDSources,
    publicHeadersPath: "./",
    cSettings: glidenOSDCSettings
)
    
// MARK: SDL

let sdlSources: [String] = [
    "SDLStubs.m"
]

let sdlExtraCSettings: [CSetting] = [
    .headerSearchPath("./")
]
let sdlCSettings: [CSetting] = sdlExtraCSettings + sharedCSettings

let sdlTarget: Target = .target(
    name: "SDL",
    path: "Sources/Compatibility/SDL/",
    sources: sdlSources,
    publicHeadersPath: "./",
    cSettings: sdlCSettings
)


// MARK: libz

let czlibProviders: [SystemPackageProvider] = [
    .brew(["zlib"]),
    .apt(["libz-dev"])
]

let czlibTarget: Target = .systemLibrary(
    name: "CZlib",
    pkgConfig: "zlib",
    providers: czlibProviders
)

// MARK: libpng
    
let libpngSources: [String] = [
    "arm/arm_init.c",
//                "arm/filter_neon.S",
    "arm/filter_neon_intrinsics.c",
    "png.c",
    "pngerror.c",
    "pngget.c",
    "pngmem.c",
    "pngpread.c",
    "pngread.c",
    "pngrio.c",
    "pngrtran.c",
    "pngrutil.c",
    "pngset.c",
    "pngtest.c",
    "pngtrans.c",
    "pngwio.c",
    "pngwrite.c",
    "pngwtran.c",
    "pngwutil.c"
].map { "png/\($0)" }

let libpngExtraCSettings: [CSetting] = [
    .define("PNG_ARM_NEON_OPT", to: "0")
]
let libpngCSettings: [CSetting] = libpngExtraCSettings + sharedCSettings

// Link with libz
let libpngLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("z")
]

let libpngTarget: Target = .target(
    name: "libpng",
    sources: libpngSources,
    publicHeadersPath: "include",
    cSettings: libpngCSettings,
    linkerSettings: libpngLinkerSettings
)

// MARK: glidenhq

let glidenhqDeps: [Target.Dependency] = ["libpng"]

let glidenhqSources: [String] = [
    "TextureFilters.cpp",
    "TextureFilters_2xsai.cpp",
    "TextureFilters_hq2x.cpp",
    "TextureFilters_hq4x.cpp",
    "TextureFilters_xbrz.cpp",
    "TxCache.cpp",
    "TxDbg_ios.mm",
    "TxFilter.cpp",
    "TxFilterExport.cpp",
    "TxHiResCache.cpp",
    "TxImage.cpp",
    "TxQuantize.cpp",
    "TxReSample.cpp",
    "TxTexCache.cpp",
    "TxUtil.cpp",
    "txWidestringWrapper.cpp"
].map { "GLideNHQ/\($0)" }

let glidenhqExtraCSettings: [CSetting] = [
    .headerSearchPath("./"),
    .headerSearchPath("./inc"),
    .headerSearchPath("./GLideNHQ"),
    .headerSearchPath("./GLideNHQ/inc"),
    .headerSearchPath("./osal/"),
    .headerSearchPath("./xxHash/"),
    .headerSearchPath("./Neon/"),
    .headerSearchPath("./mupenplus/"),
]
let glidenhqCSettings: [CSetting] = glidenhqExtraCSettings + sharedCSettings

let glidenhqTarget: Target = .target(
    name: "glidenhq",
    dependencies: glidenhqDeps,
    path: "Sources/Plugins/Video/gliden64/src/",
    sources: glidenhqSources,
    publicHeadersPath: "inc",
    cSettings: glidenhqCSettings
)

// MARK: Tests

let glidenhqTestsDeps: [Target.Dependency] = ["glidenhq"]

let glidenhqTestsTarget: Target = .testTarget(
    name: "glidenhqTests",
    dependencies: glidenhqTestsDeps
)

let pvMupenTestsDeps: [Target.Dependency] = ["PVMupen"]

let pvMupenTestsTarget: Target = .testTarget(
    name: "PVMupenTests",
    dependencies: pvMupenTestsDeps
)

let packageTargets: [Target] = [
    pvMupenTarget,
    pvMupenBridgeTarget,
    pvMupen64PlusCoreTarget,
    videoRiceTarget,
    rspHLETarget,
    rspCXD4Target,
    glideN64Target,
    glidenOSDTarget,
    sdlTarget,
    czlibTarget,
    libpngTarget,
    glidenhqTarget,
    glidenhqTestsTarget,
    pvMupenTestsTarget,
]

let package = Package(
    name: "PVMupenGameCore",
    platforms: packagePlatforms,
    products: packageProducts,
    dependencies: packageDependencies,
    targets: packageTargets,
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx11
)
