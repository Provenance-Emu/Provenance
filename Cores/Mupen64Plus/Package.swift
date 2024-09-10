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
    .define("NEON", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("OS_IOS", to: "1", .when(platforms: [.iOS, .tvOS])),
    .define("__VEC4_OPT", .when(platforms: [.iOS, .tvOS])),
    .define("__NEON_OPT", .when(platforms: [.iOS, .tvOS])),
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
    
    .define("EXCLUDED_SOURCE_FILE_NAMES", to: "3DMathNeon.cpp gSPNeon.cpp RSP_LoadMatrixNeon.cpp CRC_OPT_NEON.cpp", .when(platforms: [.macOS, .macCatalyst])),
    .define("EXCLUDED_SOURCE_FILE_NAMES", to: "3DMathNeon.cpp RSP_LoadMatrixNeon.cpp CRC_OPT_NEON.cpp", .when(platforms: [.tvOS])),
    .define("INCLUDED_SOURCE_FILE_NAMES", to: "PVDebug.c", .when(platforms: [.tvOS]))
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

let package = Package(
    name: "PVMupenGameCore",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
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

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        
        // MARK: ------- CORE -------- //
        
        .target(
            name: "PVMupen",
            dependencies: [
                "PVAudio",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVEmulatorCore",
                "PVLogging",
                "PVPlists",
                "PVSupport",
                "PVMupenBridge",
                "PVMupen64PlusCore",
//                "PVMupen64PlusRspHLE",
//                "PVMupen64PlusVideoGlideN64",
//                "PVMupen64PlusVideoRice",
                "PVRSPCXD4",
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .headerSearchPath("../Plugins/Core/Core/src/"),
            ] + sharedCSettings,
            swiftSettings: sharedSwiftSettings,
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        
        // MARK: ------- Bridge -------- //

        .target(
            name: "PVMupenBridge",
            dependencies: [
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
            ],
            cSettings: sharedCSettings + [
                .headerSearchPath("../Plugins/Core/Core/src/"),
                .headerSearchPath("../Plugins/Core/Core/src/api"),
            ]
        ),
        
    
        // MARK: PVMupen64PlusCore
        
        .target(
            name: "PVMupen64PlusCore",
            dependencies: [
                "SDL"
            ],
            path: "Sources/Plugins/Core/",
            exclude: [
                "Core/src/api/vidext_sdl2_compat.h",
            ],
            sources: [
                "api/callbacks.c",
                "api/common.c",
                "api/config.c",
                "api/debugger.c",
                "api/frontend.c",

                "asm_defines/asm_defines.c",

                "backends/clock_ctime_plus_delta.c",
                "backends/file_storage.c",

                "backends/plugins_compat/audio_plugin_compat.c",
                "backends/plugins_compat/input_plugin_compat.c",

                "device/cart/af_rtc.c",
                "device/cart/cart.c",
                "device/cart/cart_rom.c",
                "device/cart/eeprom.c",
                "device/cart/flashram.c",
                "device/cart/sram.c",

                "device/controllers/game_controller.c",
                "device/controllers/paks/mempak.c",
                "device/controllers/paks/rumblepak.c",
                "device/controllers/paks/transferpak.c",

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
                "main/md5.c",
                "main/rom.c",
                "main/savestates.c",
                "main/sdl_key_converter.c",
                "main/util.c",
                "main/workqueue.c",

                "main/xxHash/xxhash.c",

                "main/zip/ioapi.c",
                "main/zip/unzip.c",
                "main/zip/zip.c",

                "osal/dynamiclib_unix.c",
                "osal/files_macos.c",

                "plugin/dummy_audio.c",
                "plugin/dummy_input.c",
                "plugin/dummy_rsp.c",
                "plugin/dummy_video.c",
                "plugin/plugin.c"
            ].map { "Core/src/\($0)" },
//            publicHeadersPath: "./include/",
            cSettings: [
                .headerSearchPath("./Core/src/"),
            ] + sharedCSettings
        ),
        
        // MARK: - Plugins
        
        // MARK: PVMupen64PlusVideoRice
        
        .target(
            name: "PVMupen64PlusVideoRice",
            dependencies: [
                "libpng",
                "SDL"
            ],
            path: "Sources/Plugins/Video/rice/",
            sources: [
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
            ].map { "rice/src/\($0)" },
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("../../Core/Core/src/"),
                .headerSearchPath("../../Core/Core/src/api"),
                .headerSearchPath("../../Compatability/SDL/"),
            ] + sharedCSettings,
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        
        // MARK: PVMupen64PlusRspHLE
        
        .target(
            name: "PVMupen64PlusRspHLE",
            dependencies: [
            ],
            path: "Sources/Plugins/rsp/hle/src/",
            sources: [
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
            ],
            publicHeadersPath: "./",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("../../../Core/Core/src/api"),
            ] + sharedCSettings
        ),
    
        // MARK: PVRSPCXD4
        
        .target(
            name: "PVRSPCXD4",
            dependencies: [
            ],
            path: "Sources/Plugins/rsp/cxd4",
            sources: [
                "module.c",
                "osal_dynamiclib_unix.c",
                "su.c",
                "vu/add.c",
                "vu/divide.c",
                "vu/logical.c",
                "vu/multiply.c",
                "vu/select.c",
                "vu/vu.c"
            ],
            publicHeadersPath: "./",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("../../Core/Core/src/api"),
                .define("HAVE_STANDARD_INTEGER_TYPES"),
                .define("M64P_PLUGIN_API", to: "1")
            ] + sharedCSettings
        ),
        
        // MARK: PVMupen64PlusVideoGlideN64
        
        .target(
            name: "PVMupen64PlusVideoGlideN64",
            dependencies: [
                "CZlib",
                "glidenhq",
                "gliden_osd"
            ],
            path: "Sources/Plugins/Video/gliden64/src",
            sources: [
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
//                "CRC_OPT.cpp",
//                "3DMath.cpp",
//                "RSP_LoadMatrix.cpp",
//                "gSP.cpp",

                "Neon/3DMathNeon.cpp",
                "Neon/CRC_OPT_NEON.cpp",
                "Neon/RSP_LoadMatrixNeon.cpp",
                "Neon/gSPNeon.cpp",
                
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
            ],
            publicHeadersPath: "./inc",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("./osal"),
                .headerSearchPath("./inc")
            ] + sharedCSettings,
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedFramework("OpenGL", .when(platforms: [.macOS, .macCatalyst])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS]))
            ]
        ),
    
        // MARK: - Compatibility
        
        // MARK: Gliden OSD

        .target(
            name: "gliden_osd",
            path: "Sources/Compatibility/GlideN/",
            sources: [
                "gliden_osd.cpp"
            ],
            publicHeadersPath: "./",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("../../Plugins/Video/gliden64/src"),
                .headerSearchPath("../../Plugins/Video/rice/src"),
                .headerSearchPath("../../Plugins/Core/Core/src"),

                .unsafeFlags([
                    "-ffast-math",
                    "-fno-strict-aliasing",
                    "-fvisibility=hidden",
                    "-fomit-frame-pointer",
                    "-fvisibility-inlines-hidden",
                    "-flto",
                    "-fPIC",
                    "-pthread"
                ]),
            ] + sharedCSettings
        ),
    
        // MARK: SDL
        
        .target(
            name: "SDL",
            path: "Sources/Compatibility/SDL/",
            sources: [
                "SDLStubs.m"
            ],
            publicHeadersPath: "./",
            cSettings: [
                .headerSearchPath("./")
            ] + sharedCSettings
        ),
        
        
        // MARK: libz
        
        .systemLibrary(
            name: "CZlib",
            pkgConfig: "zlib",
            providers: [
                .brew(["zlib"]),
                .apt(["libz-dev"])
            ]
        ),
        
        // MARK: libpng
    
        .target(
            name: "libpng",
            sources: [
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
            ].map { "png/\($0)" },
            publicHeadersPath: "include",
            cSettings: [
                .define("PNG_ARM_NEON_OPT", to: "0")
            ] + sharedCSettings,
            // Link with libz
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        
        // MARK: glidenhq
        
        .target(
            name: "glidenhq",
            dependencies: ["libpng"],
            path: "Sources/Plugins/Video/gliden64/src/",
            sources: [
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
            ].map { "GLideNHQ/\($0)" },
            publicHeadersPath: "inc",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("./inc"),
                .headerSearchPath("./GLideNHQ"),
                .headerSearchPath("./GLideNHQ/inc"),
                .headerSearchPath("./osal/"),
                .headerSearchPath("./xxHash/"),
                .headerSearchPath("./Neon/"),
                .headerSearchPath("./mupenplus/"),
            ] + sharedCSettings
        ),
        
        // MARK: Tests
        
        .testTarget(
            name: "glidenhqTests",
            dependencies: ["glidenhq"]
        ),
        
        .testTarget(
            name: "PVMupenTests",
            dependencies: ["PVMupen"]
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx11
)
