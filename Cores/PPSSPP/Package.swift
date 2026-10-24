// swift-tools-version:6.0
import Foundation
import PackageDescription

// Source membership preserves the native archive and wrapper, including local replacements.
// No generated Xcode project or prebuilt emulator archive participates in the package build.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let nativeHeaders = ["PVPPSSPPCore/Core", "libretro_ppsspp", "libretro_ppsspp/ext/vulkan", "cmake/ffmpeg/ios/universal/include"]
// App framework search paths precede ordinary -I paths. Keep PPSSPP's legacy
// FFmpeg headers ahead of the shared app's newer FFmpeg framework headers.
let ffmpegHeaderFlags = ["-iquote", root + "/cmake/ffmpeg/ios/universal/include"]
let commonFlags = ["-fno-strict-aliasing", "-U__STRICT_ANSI__", "-Wno-nullability-completeness", "-Wno-deprecated-register"]

/// Exclude unselected branches before SwiftPM walks the large upstream test/build trees.
func exclusions(for sources: [String], resources: [String] = []) -> [String] {
    let selected = sources + resources + ["SwiftPM/include", "SwiftPM/Bridge/include"]
    func walk(_ relative: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: root + "/" + relative)) ?? []
        return entries.filter { !$0.hasPrefix(".") }.flatMap { entry -> [String] in
            let path = relative.isEmpty ? entry : relative + "/" + entry
            if selected.contains(path) { return [] }
            if selected.contains(where: { $0.hasPrefix(path + "/") }) { return walk(path) }
            return [path]
        }
    }
    return walk("")
}

// Built with explicit types and appends, not chained `+`: a loaded CI runner hit "unable to
// type-check this expression in reasonable time" on the chained version.
func nativeTarget(_ name: String, sources: [String], defines: [String], headers: [String]) -> Target {
    var flags: [String] = []
    if name == "PVPPSSPPCore" || name == "PVPPSSPPnative" {
        flags.append(contentsOf: ffmpegHeaderFlags)
    }
    for header in headers + nativeHeaders {
        flags.append("-I")
        flags.append(root + "/" + header)
    }
    flags.append(contentsOf: commonFlags)
    for define in defines {
        flags.append("-D" + define)
    }
    // zstd defines its private API before re-including public headers. Module imports freeze that API too early.
    if name == "PVPPSSPPlibzstdstatic" {
        flags.append("-fno-modules")
    }
    let cFlags: CSetting = .unsafeFlags(flags)
    let cxxFlags: CXXSetting = .unsafeFlags(flags)
    return .target(name: name, path: ".", exclude: exclusions(for: sources), sources: sources,
                   publicHeadersPath: "SwiftPM/include",
                   cSettings: [cFlags],
                   cxxSettings: [cxxFlags])
}

let nativeCommon = nativeTarget("PVPPSSPPCommon", sources: [
    "libretro_ppsspp/Common/ABI.cpp",
    "libretro_ppsspp/Common/Arm64Emitter.cpp",
    "libretro_ppsspp/Common/ArmCPUDetect.cpp",
    "libretro_ppsspp/Common/ArmEmitter.cpp",
    "libretro_ppsspp/Common/Buffer.cpp",
    "libretro_ppsspp/Common/CPUDetect.cpp",
    "libretro_ppsspp/Common/ConsoleListener.cpp",
    "SwiftPM/Native/MD5.cpp",
    "libretro_ppsspp/Common/Crypto/sha1.cpp",
    "libretro_ppsspp/Common/Crypto/sha256.cpp",
    "libretro_ppsspp/Common/Data/Color/RGBAUtil.cpp",
    "libretro_ppsspp/Common/Data/Convert/ColorConv.cpp",
    "libretro_ppsspp/Common/Data/Convert/SmallDataConvert.cpp",
    "libretro_ppsspp/Common/Data/Encoding/Base64.cpp",
    "libretro_ppsspp/Common/Data/Encoding/Compression.cpp",
    "libretro_ppsspp/Common/Data/Encoding/Utf8.cpp",
    "libretro_ppsspp/Common/Data/Format/DDSLoad.cpp",
    "libretro_ppsspp/Common/Data/Format/IniFile.cpp",
    "libretro_ppsspp/Common/Data/Format/JSONReader.cpp",
    "libretro_ppsspp/Common/Data/Format/JSONWriter.cpp",
    "libretro_ppsspp/Common/Data/Format/PNGLoad.cpp",
    "libretro_ppsspp/Common/Data/Format/RIFF.cpp",
    "libretro_ppsspp/Common/Data/Format/ZIMLoad.cpp",
    "libretro_ppsspp/Common/Data/Format/ZIMSave.cpp",
    "libretro_ppsspp/Common/Data/Hash/Hash.cpp",
    "libretro_ppsspp/Common/Data/Text/I18n.cpp",
    "libretro_ppsspp/Common/Data/Text/Parsers.cpp",
    "libretro_ppsspp/Common/Data/Text/WrapText.cpp",
    "libretro_ppsspp/Common/ExceptionHandlerSetup.cpp",
    "libretro_ppsspp/Common/FakeCPUDetect.cpp",
    "libretro_ppsspp/Common/File/AndroidContentURI.cpp",
    "libretro_ppsspp/Common/File/AndroidStorage.cpp",
    "libretro_ppsspp/Common/File/DirListing.cpp",
    "libretro_ppsspp/Common/File/DiskFree.cpp",
    "libretro_ppsspp/Common/File/FileDescriptor.cpp",
    "libretro_ppsspp/Common/File/FileUtil.cpp",
    "libretro_ppsspp/Common/File/Path.cpp",
    "libretro_ppsspp/Common/File/PathBrowser.cpp",
    "libretro_ppsspp/Common/File/VFS/DirectoryReader.cpp",
    "libretro_ppsspp/Common/File/VFS/VFS.cpp",
    "libretro_ppsspp/Common/File/VFS/ZipFileReader.cpp",
    "libretro_ppsspp/Common/GPU/GPUBackendCommon.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/DataFormatGL.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLDebugLog.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLFeatures.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLFrameData.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLMemory.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLQueueRunner.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLRenderManager.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/GLSLProgram.cpp",
    "libretro_ppsspp/Common/GPU/OpenGL/gl3stub.c",
    "libretro_ppsspp/Common/GPU/OpenGL/thin3d_gl.cpp",
    "libretro_ppsspp/Common/GPU/Shader.cpp",
    "libretro_ppsspp/Common/GPU/ShaderTranslation.cpp",
    "libretro_ppsspp/Common/GPU/ShaderWriter.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanBarrier.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanContext.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanDebug.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanFrameData.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanFramebuffer.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanImage.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanLoader.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanMemory.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanProfiler.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanQueueRunner.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/VulkanRenderManager.cpp",
    "libretro_ppsspp/Common/GPU/Vulkan/thin3d_vulkan.cpp",
    "libretro_ppsspp/Common/GPU/thin3d.cpp",
    "libretro_ppsspp/Common/Input/GestureDetector.cpp",
    "libretro_ppsspp/Common/Input/InputState.cpp",
    "libretro_ppsspp/Common/Log.cpp",
    "libretro_ppsspp/Common/LogManager.cpp",
    "libretro_ppsspp/Common/LogReporting.cpp",
    "libretro_ppsspp/Common/Math/Statistics.cpp",
    "libretro_ppsspp/Common/Math/curves.cpp",
    "libretro_ppsspp/Common/Math/expression_parser.cpp",
    "libretro_ppsspp/Common/Math/fast/fast_matrix.c",
    "libretro_ppsspp/Common/Math/lin/matrix4x4.cpp",
    "libretro_ppsspp/Common/Math/lin/vec3.cpp",
    "libretro_ppsspp/Common/Math/math_util.cpp",
    "libretro_ppsspp/Common/MemArenaAndroid.cpp",
    "libretro_ppsspp/Common/MemArenaPosix.cpp",
    "libretro_ppsspp/Common/MemArenaWin32.cpp",
    "libretro_ppsspp/Common/MemoryUtil.cpp",
    "libretro_ppsspp/Common/MipsCPUDetect.cpp",
    "libretro_ppsspp/Common/MipsEmitter.cpp",
    "libretro_ppsspp/Common/Net/HTTPClient.cpp",
    "libretro_ppsspp/Common/Net/HTTPHeaders.cpp",
    "libretro_ppsspp/Common/Net/HTTPServer.cpp",
    "libretro_ppsspp/Common/Net/NetBuffer.cpp",
    "libretro_ppsspp/Common/Net/Resolve.cpp",
    "libretro_ppsspp/Common/Net/Sinks.cpp",
    "libretro_ppsspp/Common/Net/URL.cpp",
    "libretro_ppsspp/Common/Net/WebsocketServer.cpp",
    "libretro_ppsspp/Common/OSVersion.cpp",
    "libretro_ppsspp/Common/Profiler/Profiler.cpp",
    "libretro_ppsspp/Common/Render/DrawBuffer.cpp",
    "libretro_ppsspp/Common/Render/ManagedTexture.cpp",
    "libretro_ppsspp/Common/Render/Text/draw_text.cpp",
    "libretro_ppsspp/Common/Render/Text/draw_text_android.cpp",
    "libretro_ppsspp/Common/Render/Text/draw_text_uwp.cpp",
    "libretro_ppsspp/Common/Render/Text/draw_text_win.cpp",
    "libretro_ppsspp/Common/Render/TextureAtlas.cpp",
    "libretro_ppsspp/Common/RiscVCPUDetect.cpp",
    "libretro_ppsspp/Common/RiscVEmitter.cpp",
    "libretro_ppsspp/Common/Serialize/Serializer.cpp",
    "libretro_ppsspp/Common/StringUtils.cpp",
    "libretro_ppsspp/Common/SysError.cpp",
    "libretro_ppsspp/Common/System/Display.cpp",
    "libretro_ppsspp/Common/System/Request.cpp",
    "libretro_ppsspp/Common/Thread/ParallelLoop.cpp",
    "libretro_ppsspp/Common/Thread/ThreadManager.cpp",
    "libretro_ppsspp/Common/Thread/ThreadUtil.cpp",
    "SwiftPM/Native/Thunk.cpp",
    "libretro_ppsspp/Common/TimeUtil.cpp",
    "libretro_ppsspp/Common/UI/AsyncImageFileView.cpp",
    "libretro_ppsspp/Common/UI/Context.cpp",
    "libretro_ppsspp/Common/UI/PopupScreens.cpp",
    "libretro_ppsspp/Common/UI/Root.cpp",
    "libretro_ppsspp/Common/UI/Screen.cpp",
    "libretro_ppsspp/Common/UI/ScrollView.cpp",
    "libretro_ppsspp/Common/UI/Tween.cpp",
    "libretro_ppsspp/Common/UI/UI.cpp",
    "libretro_ppsspp/Common/UI/UIScreen.cpp",
    "libretro_ppsspp/Common/UI/View.cpp",
    "libretro_ppsspp/Common/UI/ViewGroup.cpp",
    "libretro_ppsspp/Common/VR/OpenXRLoader.cpp",
    "libretro_ppsspp/Common/VR/PPSSPPVR.cpp",
    "libretro_ppsspp/Common/VR/VRBase.cpp",
    "libretro_ppsspp/Common/VR/VRFramebuffer.cpp",
    "libretro_ppsspp/Common/VR/VRInput.cpp",
    "libretro_ppsspp/Common/VR/VRMath.cpp",
    "libretro_ppsspp/Common/VR/VRRenderer.cpp",
    "libretro_ppsspp/Common/x64Analyzer.cpp",
    "libretro_ppsspp/Common/x64Emitter.cpp",
    "libretro_ppsspp/Core/MIPS/JitCommon/JitBlockCache.cpp",
    "libretro_ppsspp/Core/MIPS/JitCommon/JitCommon.cpp",
    "libretro_ppsspp/Core/MIPS/JitCommon/JitState.cpp",
    "libretro_ppsspp/Core/MIPS/fake/FakeJit.cpp",
    "libretro_ppsspp/Core/Util/DisArm64.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB",
    "STACK_LINE_READER_BUFFER_SIZE=1024"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake",
    "libretro_ppsspp/ext/snappy/.",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include"
])

let nativeCore = nativeTarget("PVPPSSPPCore", sources: [
    "cmake/git-version.cpp",
    "libretro_ppsspp/Core/Compatibility.cpp",
    "libretro_ppsspp/Core/Config.cpp",
    "libretro_ppsspp/Core/ConfigSettings.cpp",
    "libretro_ppsspp/Core/ControlMapper.cpp",
    "libretro_ppsspp/Core/Core.cpp",
    "libretro_ppsspp/Core/CoreTiming.cpp",
    "libretro_ppsspp/Core/CwCheat.cpp",
    "libretro_ppsspp/Core/Debugger/Breakpoints.cpp",
    "libretro_ppsspp/Core/Debugger/DisassemblyManager.cpp",
    "libretro_ppsspp/Core/Debugger/MemBlockInfo.cpp",
    "libretro_ppsspp/Core/Debugger/SymbolMap.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/BreakpointSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/CPUCoreSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/DisasmSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/GPUBufferSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/GPURecordSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/GPUStatsSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/GameBroadcaster.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/GameSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/HLESubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/InputBroadcaster.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/InputSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/LogBroadcaster.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/MemoryInfoSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/MemorySubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/ReplaySubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/SteppingBroadcaster.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/SteppingSubscriber.cpp",
    "libretro_ppsspp/Core/Debugger/WebSocket/WebSocketUtils.cpp",
    "libretro_ppsspp/Core/Dialog/PSPDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPGamedataInstallDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPMsgDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPNetconfDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPNpSigninDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPOskDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPPlaceholderDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPSaveDialog.cpp",
    "libretro_ppsspp/Core/Dialog/PSPScreenshotDialog.cpp",
    "libretro_ppsspp/Core/Dialog/SavedataParam.cpp",
    "libretro_ppsspp/Core/ELF/ElfReader.cpp",
    "libretro_ppsspp/Core/ELF/PBPReader.cpp",
    "libretro_ppsspp/Core/ELF/ParamSFO.cpp",
    "libretro_ppsspp/Core/ELF/PrxDecrypter.cpp",
    "libretro_ppsspp/Core/FileLoaders/CachingFileLoader.cpp",
    "libretro_ppsspp/Core/FileLoaders/DiskCachingFileLoader.cpp",
    "libretro_ppsspp/Core/FileLoaders/HTTPFileLoader.cpp",
    "libretro_ppsspp/Core/FileLoaders/LocalFileLoader.cpp",
    "libretro_ppsspp/Core/FileLoaders/RamCachingFileLoader.cpp",
    "libretro_ppsspp/Core/FileLoaders/RetryingFileLoader.cpp",
    "libretro_ppsspp/Core/FileSystems/BlobFileSystem.cpp",
    "libretro_ppsspp/Core/FileSystems/BlockDevices.cpp",
    "libretro_ppsspp/Core/FileSystems/DirectoryFileSystem.cpp",
    "libretro_ppsspp/Core/FileSystems/FileSystem.cpp",
    "libretro_ppsspp/Core/FileSystems/ISOFileSystem.cpp",
    "libretro_ppsspp/Core/FileSystems/MetaFileSystem.cpp",
    "libretro_ppsspp/Core/FileSystems/VirtualDiscFileSystem.cpp",
    "libretro_ppsspp/Core/FileSystems/tlzrc.cpp",
    "libretro_ppsspp/Core/Font/PGF.cpp",
    "libretro_ppsspp/Core/HDRemaster.cpp",
    "libretro_ppsspp/Core/HLE/HLE.cpp",
    "libretro_ppsspp/Core/HLE/HLEHelperThread.cpp",
    "libretro_ppsspp/Core/HLE/HLETables.cpp",
    "libretro_ppsspp/Core/HLE/KUBridge.cpp",
    "libretro_ppsspp/Core/HLE/Plugins.cpp",
    "libretro_ppsspp/Core/HLE/ReplaceTables.cpp",
    "libretro_ppsspp/Core/HLE/__sceAudio.cpp",
    "libretro_ppsspp/Core/HLE/proAdhoc.cpp",
    "libretro_ppsspp/Core/HLE/proAdhocServer.cpp",
    "libretro_ppsspp/Core/HLE/sceAdler.cpp",
    "libretro_ppsspp/Core/HLE/sceAtrac.cpp",
    "libretro_ppsspp/Core/HLE/sceAudio.cpp",
    "libretro_ppsspp/Core/HLE/sceAudioRouting.cpp",
    "libretro_ppsspp/Core/HLE/sceAudiocodec.cpp",
    "libretro_ppsspp/Core/HLE/sceCcc.cpp",
    "libretro_ppsspp/Core/HLE/sceChnnlsv.cpp",
    "libretro_ppsspp/Core/HLE/sceCtrl.cpp",
    "libretro_ppsspp/Core/HLE/sceDeflt.cpp",
    "libretro_ppsspp/Core/HLE/sceDisplay.cpp",
    "libretro_ppsspp/Core/HLE/sceDmac.cpp",
    "libretro_ppsspp/Core/HLE/sceFont.cpp",
    "libretro_ppsspp/Core/HLE/sceG729.cpp",
    "libretro_ppsspp/Core/HLE/sceGameUpdate.cpp",
    "libretro_ppsspp/Core/HLE/sceGe.cpp",
    "libretro_ppsspp/Core/HLE/sceHeap.cpp",
    "libretro_ppsspp/Core/HLE/sceHprm.cpp",
    "libretro_ppsspp/Core/HLE/sceHttp.cpp",
    "libretro_ppsspp/Core/HLE/sceImpose.cpp",
    "libretro_ppsspp/Core/HLE/sceIo.cpp",
    "libretro_ppsspp/Core/HLE/sceJpeg.cpp",
    "libretro_ppsspp/Core/HLE/sceKernel.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelAlarm.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelEventFlag.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelHeap.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelInterrupt.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelMbx.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelMemory.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelModule.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelMsgPipe.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelMutex.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelSemaphore.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelThread.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelTime.cpp",
    "libretro_ppsspp/Core/HLE/sceKernelVTimer.cpp",
    "SwiftPM/Native/SceMD5.cpp",
    "libretro_ppsspp/Core/HLE/sceMp3.cpp",
    "libretro_ppsspp/Core/HLE/sceMp4.cpp",
    "libretro_ppsspp/Core/HLE/sceMpeg.cpp",
    "libretro_ppsspp/Core/HLE/sceMt19937.cpp",
    "libretro_ppsspp/Core/HLE/sceNet.cpp",
    "libretro_ppsspp/Core/HLE/sceNetAdhoc.cpp",
    "libretro_ppsspp/Core/HLE/sceNp.cpp",
    "libretro_ppsspp/Core/HLE/sceNp2.cpp",
    "libretro_ppsspp/Core/HLE/sceOpenPSID.cpp",
    "libretro_ppsspp/Core/HLE/sceP3da.cpp",
    "libretro_ppsspp/Core/HLE/sceParseHttp.cpp",
    "libretro_ppsspp/Core/HLE/sceParseUri.cpp",
    "libretro_ppsspp/Core/HLE/scePauth.cpp",
    "libretro_ppsspp/Core/HLE/scePower.cpp",
    "libretro_ppsspp/Core/HLE/scePsmf.cpp",
    "libretro_ppsspp/Core/HLE/scePspNpDrm_user.cpp",
    "libretro_ppsspp/Core/HLE/sceRtc.cpp",
    "libretro_ppsspp/Core/HLE/sceSas.cpp",
    "libretro_ppsspp/Core/HLE/sceSfmt19937.cpp",
    "libretro_ppsspp/Core/HLE/sceSha256.cpp",
    "libretro_ppsspp/Core/HLE/sceSsl.cpp",
    "libretro_ppsspp/Core/HLE/sceUmd.cpp",
    "libretro_ppsspp/Core/HLE/sceUsb.cpp",
    "libretro_ppsspp/Core/HLE/sceUsbAcc.cpp",
    "libretro_ppsspp/Core/HLE/sceUsbCam.cpp",
    "libretro_ppsspp/Core/HLE/sceUsbGps.cpp",
    "libretro_ppsspp/Core/HLE/sceUsbMic.cpp",
    "libretro_ppsspp/Core/HLE/sceUtility.cpp",
    "libretro_ppsspp/Core/HLE/sceVaudio.cpp",
    "libretro_ppsspp/Core/HW/AsyncIOManager.cpp",
    "libretro_ppsspp/Core/HW/BufferQueue.cpp",
    "libretro_ppsspp/Core/HW/Camera.cpp",
    "libretro_ppsspp/Core/HW/Display.cpp",
    "libretro_ppsspp/Core/HW/MediaEngine.cpp",
    "libretro_ppsspp/Core/HW/MemoryStick.cpp",
    "libretro_ppsspp/Core/HW/MpegDemux.cpp",
    "libretro_ppsspp/Core/HW/SasAudio.cpp",
    "libretro_ppsspp/Core/HW/SasReverb.cpp",
    "libretro_ppsspp/Core/HW/SimpleAudioDec.cpp",
    "libretro_ppsspp/Core/HW/StereoResampler.cpp",
    "libretro_ppsspp/Core/Instance.cpp",
    "libretro_ppsspp/Core/KeyMap.cpp",
    "libretro_ppsspp/Core/KeyMapDefaults.cpp",
    "libretro_ppsspp/Core/Loaders.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmAsm.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompALU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompBranch.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompFPU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompLoadStore.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompReplace.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompVFPU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompVFPUNEON.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmCompVFPUNEONUtil.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmJit.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmRegCache.cpp",
    "libretro_ppsspp/Core/MIPS/ARM/ArmRegCacheFPU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64Asm.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64CompALU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64CompBranch.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64CompFPU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64CompLoadStore.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64CompReplace.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64CompVFPU.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64Jit.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64RegCache.cpp",
    "libretro_ppsspp/Core/MIPS/ARM64/Arm64RegCacheFPU.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRCompALU.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRCompBranch.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRCompFPU.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRCompLoadStore.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRCompVFPU.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRFrontend.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRInst.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRInterpreter.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRJit.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRPassSimplify.cpp",
    "libretro_ppsspp/Core/MIPS/IR/IRRegCache.cpp",
    "libretro_ppsspp/Core/MIPS/MIPS.cpp",
    "libretro_ppsspp/Core/MIPS/MIPS/MipsJit.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSAnalyst.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSAsm.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSCodeUtils.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSDebugInterface.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSDis.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSDisVFPU.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSInt.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSIntVFPU.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSStackWalk.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSTables.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSVFPUFallbacks.cpp",
    "libretro_ppsspp/Core/MIPS/MIPSVFPUUtils.cpp",
    "libretro_ppsspp/Core/MIPS/x86/Asm.cpp",
    "libretro_ppsspp/Core/MIPS/x86/CompALU.cpp",
    "libretro_ppsspp/Core/MIPS/x86/CompBranch.cpp",
    "libretro_ppsspp/Core/MIPS/x86/CompFPU.cpp",
    "libretro_ppsspp/Core/MIPS/x86/CompLoadStore.cpp",
    "libretro_ppsspp/Core/MIPS/x86/CompReplace.cpp",
    "libretro_ppsspp/Core/MIPS/x86/CompVFPU.cpp",
    "libretro_ppsspp/Core/MIPS/x86/Jit.cpp",
    "libretro_ppsspp/Core/MIPS/x86/JitSafeMem.cpp",
    "libretro_ppsspp/Core/MIPS/x86/RegCache.cpp",
    "libretro_ppsspp/Core/MIPS/x86/RegCacheFPU.cpp",
    "libretro_ppsspp/Core/MemFault.cpp",
    "libretro_ppsspp/Core/MemMap.cpp",
    "libretro_ppsspp/Core/MemMapFunctions.cpp",
    "libretro_ppsspp/Core/PSPLoaders.cpp",
    "libretro_ppsspp/Core/Replay.cpp",
    "libretro_ppsspp/Core/Reporting.cpp",
    "libretro_ppsspp/Core/SaveState.cpp",
    "libretro_ppsspp/Core/Screenshot.cpp",
    "libretro_ppsspp/Core/System.cpp",
    "libretro_ppsspp/Core/ThreadPools.cpp",
    "libretro_ppsspp/Core/TiltEventProcessor.cpp",
    "libretro_ppsspp/Core/Util/AudioFormat.cpp",
    "libretro_ppsspp/Core/Util/BlockAllocator.cpp",
    "libretro_ppsspp/Core/Util/GameManager.cpp",
    "libretro_ppsspp/Core/Util/PPGeDraw.cpp",
    "libretro_ppsspp/Core/Util/PortManager.cpp",
    "libretro_ppsspp/Core/WebServer.cpp",
    "libretro_ppsspp/GPU/Common/DepalettizeShaderCommon.cpp",
    "libretro_ppsspp/GPU/Common/DepthBufferCommon.cpp",
    "libretro_ppsspp/GPU/Common/Draw2D.cpp",
    "libretro_ppsspp/GPU/Common/DrawEngineCommon.cpp",
    "libretro_ppsspp/GPU/Common/FragmentShaderGenerator.cpp",
    "libretro_ppsspp/GPU/Common/FramebufferManagerCommon.cpp",
    "libretro_ppsspp/GPU/Common/GPUDebugInterface.cpp",
    "libretro_ppsspp/GPU/Common/GPUStateUtils.cpp",
    "libretro_ppsspp/GPU/Common/GeometryShaderGenerator.cpp",
    "libretro_ppsspp/GPU/Common/IndexGenerator.cpp",
    "libretro_ppsspp/GPU/Common/PostShader.cpp",
    "libretro_ppsspp/GPU/Common/PresentationCommon.cpp",
    "libretro_ppsspp/GPU/Common/ReinterpretFramebuffer.cpp",
    "libretro_ppsspp/GPU/Common/ReplacedTexture.cpp",
    "libretro_ppsspp/GPU/Common/ShaderCommon.cpp",
    "libretro_ppsspp/GPU/Common/ShaderId.cpp",
    "libretro_ppsspp/GPU/Common/ShaderUniforms.cpp",
    "libretro_ppsspp/GPU/Common/SoftwareTransformCommon.cpp",
    "libretro_ppsspp/GPU/Common/SplineCommon.cpp",
    "libretro_ppsspp/GPU/Common/StencilCommon.cpp",
    "libretro_ppsspp/GPU/Common/TextureCacheCommon.cpp",
    "libretro_ppsspp/GPU/Common/TextureDecoder.cpp",
    "libretro_ppsspp/GPU/Common/TextureReplacer.cpp",
    "libretro_ppsspp/GPU/Common/TextureScalerCommon.cpp",
    "libretro_ppsspp/GPU/Common/TextureShaderCommon.cpp",
    "libretro_ppsspp/GPU/Common/TransformCommon.cpp",
    "libretro_ppsspp/GPU/Common/VertexDecoderArm.cpp",
    "libretro_ppsspp/GPU/Common/VertexDecoderArm64.cpp",
    "libretro_ppsspp/GPU/Common/VertexDecoderCommon.cpp",
    "libretro_ppsspp/GPU/Common/VertexDecoderRiscV.cpp",
    "libretro_ppsspp/GPU/Common/VertexDecoderX86.cpp",
    "libretro_ppsspp/GPU/Common/VertexShaderGenerator.cpp",
    "libretro_ppsspp/GPU/Debugger/Breakpoints.cpp",
    "libretro_ppsspp/GPU/Debugger/Debugger.cpp",
    "libretro_ppsspp/GPU/Debugger/GECommandTable.cpp",
    "libretro_ppsspp/GPU/Debugger/Playback.cpp",
    "libretro_ppsspp/GPU/Debugger/Record.cpp",
    "libretro_ppsspp/GPU/Debugger/Stepping.cpp",
    "libretro_ppsspp/GPU/GLES/DrawEngineGLES.cpp",
    "libretro_ppsspp/GPU/GLES/FragmentTestCacheGLES.cpp",
    "libretro_ppsspp/GPU/GLES/FramebufferManagerGLES.cpp",
    "libretro_ppsspp/GPU/GLES/GPU_GLES.cpp",
    "libretro_ppsspp/GPU/GLES/ShaderManagerGLES.cpp",
    "libretro_ppsspp/GPU/GLES/StateMappingGLES.cpp",
    "libretro_ppsspp/GPU/GLES/StencilBufferGLES.cpp",
    "libretro_ppsspp/GPU/GLES/TextureCacheGLES.cpp",
    "libretro_ppsspp/GPU/GPU.cpp",
    "libretro_ppsspp/GPU/GPUCommon.cpp",
    "libretro_ppsspp/GPU/GPUCommonHW.cpp",
    "libretro_ppsspp/GPU/GPUState.cpp",
    "libretro_ppsspp/GPU/GeConstants.cpp",
    "libretro_ppsspp/GPU/GeDisasm.cpp",
    "libretro_ppsspp/GPU/Math3D.cpp",
    "libretro_ppsspp/GPU/Software/BinManager.cpp",
    "libretro_ppsspp/GPU/Software/Clipper.cpp",
    "libretro_ppsspp/GPU/Software/DrawPixel.cpp",
    "libretro_ppsspp/GPU/Software/DrawPixelX86.cpp",
    "libretro_ppsspp/GPU/Software/FuncId.cpp",
    "libretro_ppsspp/GPU/Software/Lighting.cpp",
    "libretro_ppsspp/GPU/Software/Rasterizer.cpp",
    "libretro_ppsspp/GPU/Software/RasterizerRectangle.cpp",
    "libretro_ppsspp/GPU/Software/RasterizerRegCache.cpp",
    "libretro_ppsspp/GPU/Software/Sampler.cpp",
    "libretro_ppsspp/GPU/Software/SamplerX86.cpp",
    "libretro_ppsspp/GPU/Software/SoftGpu.cpp",
    "libretro_ppsspp/GPU/Software/TransformUnit.cpp",
    "libretro_ppsspp/GPU/Vulkan/DebugVisVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/DrawEngineVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/FramebufferManagerVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/GPU_Vulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/PipelineManagerVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/ShaderManagerVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/StateMappingVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/TextureCacheVulkan.cpp",
    "libretro_ppsspp/GPU/Vulkan/VulkanUtil.cpp",
    "libretro_ppsspp/ext/disarm.cpp",
    "libretro_ppsspp/ext/riscv-disas.cpp"
], defines: [
    "USE_FFMPEG=1",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB",
    "STACK_LINE_READER_BUFFER_SIZE=1024"
], headers: [
    "cmake/ffmpeg/ios/universal/include",
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake",
    "libretro_ppsspp/ext/snappy/.",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include",
    "libretro_ppsspp/ext/glslang/glslang/..",
    "cmake/include",
    "libretro_ppsspp/ext/glslang/SPIRV/..",
    "libretro_ppsspp/ext/SPIRV-Cross-build/../SPIRV-Cross",
    "libretro_ppsspp/ext/armips",
    "libretro_ppsspp/ext/armips/ext/tinyformat",
    "libretro_ppsspp/ext/armips/ext/filesystem/include"
])

let nativeGenericCodeGen = nativeTarget("PVPPSSPPGenericCodeGen", sources: [
    "libretro_ppsspp/ext/glslang/glslang/GenericCodeGen/CodeGen.cpp",
    "libretro_ppsspp/ext/glslang/glslang/GenericCodeGen/Link.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp"
])

let nativeHLSL = nativeTarget("PVPPSSPPHLSL", sources: [
    "libretro_ppsspp/ext/glslang/hlsl/stub.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp"
])

let nativeMachineIndependent = nativeTarget("PVPPSSPPMachineIndependent", sources: [
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslAttributes.cpp",
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslGrammar.cpp",
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslOpMap.cpp",
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslParseHelper.cpp",
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslParseables.cpp",
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslScanContext.cpp",
    "libretro_ppsspp/ext/glslang/glslang/HLSL/hlslTokenStream.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "cmake/include"
])

let nativeOGLCompiler = nativeTarget("PVPPSSPPOGLCompiler", sources: [
    "libretro_ppsspp/ext/glslang/OGLCompilersDLL/InitializeDll.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp"
])

let nativeOSDependent = nativeTarget("PVPPSSPPOSDependent", sources: [
    "libretro_ppsspp/ext/glslang/glslang/OSDependent/Unix/ossource.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp"
])

let nativeSPIRV = nativeTarget("PVPPSSPPSPIRV", sources: [
    "libretro_ppsspp/ext/glslang/SPIRV/CInterface/spirv_c_interface.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/glslang/SPIRV/..",
    "cmake/include"
])

let nativeArmips = nativeTarget("PVPPSSPParmips", sources: [
    "libretro_ppsspp/ext/armips/Archs/ARM/Arm.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/ArmElfRelocator.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/ArmExpressionFunctions.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/ArmOpcodes.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/ArmParser.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/CArmInstruction.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/CThumbInstruction.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/Pool.cpp",
    "libretro_ppsspp/ext/armips/Archs/ARM/ThumbOpcodes.cpp",
    "libretro_ppsspp/ext/armips/Archs/Architecture.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/CMipsInstruction.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/Mips.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/MipsElfFile.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/MipsElfRelocator.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/MipsExpressionFunctions.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/MipsMacros.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/MipsOpcodes.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/MipsParser.cpp",
    "libretro_ppsspp/ext/armips/Archs/MIPS/PsxRelocator.cpp",
    "libretro_ppsspp/ext/armips/Archs/SuperH/CShInstruction.cpp",
    "libretro_ppsspp/ext/armips/Archs/SuperH/ShElfRelocator.cpp",
    "libretro_ppsspp/ext/armips/Archs/SuperH/ShExpressionFunctions.cpp",
    "libretro_ppsspp/ext/armips/Archs/SuperH/ShOpcodes.cpp",
    "libretro_ppsspp/ext/armips/Archs/SuperH/ShParser.cpp",
    "libretro_ppsspp/ext/armips/Archs/SuperH/SuperH.cpp",
    "libretro_ppsspp/ext/armips/Commands/CAssemblerCommand.cpp",
    "libretro_ppsspp/ext/armips/Commands/CAssemblerLabel.cpp",
    "libretro_ppsspp/ext/armips/Commands/CDirectiveArea.cpp",
    "libretro_ppsspp/ext/armips/Commands/CDirectiveConditional.cpp",
    "libretro_ppsspp/ext/armips/Commands/CDirectiveData.cpp",
    "libretro_ppsspp/ext/armips/Commands/CDirectiveFile.cpp",
    "libretro_ppsspp/ext/armips/Commands/CDirectiveMessage.cpp",
    "libretro_ppsspp/ext/armips/Commands/CommandSequence.cpp",
    "libretro_ppsspp/ext/armips/Core/Allocations.cpp",
    "libretro_ppsspp/ext/armips/Core/Assembler.cpp",
    "libretro_ppsspp/ext/armips/Core/Common.cpp",
    "libretro_ppsspp/ext/armips/Core/ELF/ElfFile.cpp",
    "libretro_ppsspp/ext/armips/Core/ELF/ElfRelocator.cpp",
    "libretro_ppsspp/ext/armips/Core/Expression.cpp",
    "libretro_ppsspp/ext/armips/Core/ExpressionFunctionHandler.cpp",
    "libretro_ppsspp/ext/armips/Core/ExpressionFunctions.cpp",
    "libretro_ppsspp/ext/armips/Core/FileManager.cpp",
    "libretro_ppsspp/ext/armips/Core/Misc.cpp",
    "libretro_ppsspp/ext/armips/Core/SymbolData.cpp",
    "libretro_ppsspp/ext/armips/Core/SymbolTable.cpp",
    "libretro_ppsspp/ext/armips/Core/Types.cpp",
    "libretro_ppsspp/ext/armips/Parser/DirectivesParser.cpp",
    "libretro_ppsspp/ext/armips/Parser/ExpressionParser.cpp",
    "libretro_ppsspp/ext/armips/Parser/Parser.cpp",
    "libretro_ppsspp/ext/armips/Parser/Tokenizer.cpp",
    "libretro_ppsspp/ext/armips/Util/ByteArray.cpp",
    "libretro_ppsspp/ext/armips/Util/CRC.cpp",
    "libretro_ppsspp/ext/armips/Util/EncodingTable.cpp",
    "libretro_ppsspp/ext/armips/Util/FileClasses.cpp",
    "libretro_ppsspp/ext/armips/Util/FileSystem.cpp",
    "libretro_ppsspp/ext/armips/Util/Util.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/armips",
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/armips/ext/tinyformat",
    "libretro_ppsspp/ext/armips/ext/filesystem/include"
])

let nativeBasisuniversal = nativeTarget("PVPPSSPPbasisuniversal", sources: [
    "libretro_ppsspp/ext/basis_universal/basisu_transcoder.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeCityhash = nativeTarget("PVPPSSPPcityhash", sources: [
    "libretro_ppsspp/ext/cityhash/city.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/cityhash",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeGason = nativeTarget("PVPPSSPPgason", sources: [
    "libretro_ppsspp/ext/gason/gason.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeGlslang = nativeTarget("PVPPSSPPglslang", sources: [
    "libretro_ppsspp/ext/glslang/glslang/CInterface/glslang_c_interface.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/glslang/glslang/..",
    "cmake/include"
])

let nativeGlslangdefaultresourcelimits = nativeTarget("PVPPSSPPglslangdefaultresourcelimits", sources: [
    "libretro_ppsspp/ext/glslang/glslang/ResourceLimits/ResourceLimits.cpp",
    "libretro_ppsspp/ext/glslang/glslang/ResourceLimits/resource_limits_c.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/glslang/glslang/.."
])

let nativeKirk = nativeTarget("PVPPSSPPkirk", sources: [
    "libretro_ppsspp/ext/libkirk/AES.c",
    "libretro_ppsspp/ext/libkirk/SHA1.c",
    "libretro_ppsspp/ext/libkirk/amctrl.c",
    "libretro_ppsspp/ext/libkirk/bn.c",
    "libretro_ppsspp/ext/libkirk/ec.c",
    "libretro_ppsspp/ext/libkirk/kirk_engine.c"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/libkirk",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeLibzip = nativeTarget("PVPPSSPPlibzip", sources: [
    "libretro_ppsspp/ext/libzip/zip_add.c",
    "libretro_ppsspp/ext/libzip/zip_add_dir.c",
    "libretro_ppsspp/ext/libzip/zip_add_entry.c",
    "libretro_ppsspp/ext/libzip/zip_algorithm_deflate.c",
    "libretro_ppsspp/ext/libzip/zip_buffer.c",
    "libretro_ppsspp/ext/libzip/zip_close.c",
    "libretro_ppsspp/ext/libzip/zip_delete.c",
    "libretro_ppsspp/ext/libzip/zip_dir_add.c",
    "libretro_ppsspp/ext/libzip/zip_dirent.c",
    "libretro_ppsspp/ext/libzip/zip_discard.c",
    "libretro_ppsspp/ext/libzip/zip_entry.c",
    "libretro_ppsspp/ext/libzip/zip_err_str.c",
    "libretro_ppsspp/ext/libzip/zip_error.c",
    "libretro_ppsspp/ext/libzip/zip_error_clear.c",
    "libretro_ppsspp/ext/libzip/zip_error_get.c",
    "libretro_ppsspp/ext/libzip/zip_error_get_sys_type.c",
    "libretro_ppsspp/ext/libzip/zip_error_strerror.c",
    "libretro_ppsspp/ext/libzip/zip_error_to_str.c",
    "libretro_ppsspp/ext/libzip/zip_extra_field.c",
    "libretro_ppsspp/ext/libzip/zip_extra_field_api.c",
    "libretro_ppsspp/ext/libzip/zip_fclose.c",
    "libretro_ppsspp/ext/libzip/zip_fdopen.c",
    "libretro_ppsspp/ext/libzip/zip_file_add.c",
    "libretro_ppsspp/ext/libzip/zip_file_error_clear.c",
    "libretro_ppsspp/ext/libzip/zip_file_error_get.c",
    "libretro_ppsspp/ext/libzip/zip_file_get_comment.c",
    "libretro_ppsspp/ext/libzip/zip_file_get_external_attributes.c",
    "libretro_ppsspp/ext/libzip/zip_file_get_offset.c",
    "libretro_ppsspp/ext/libzip/zip_file_rename.c",
    "libretro_ppsspp/ext/libzip/zip_file_replace.c",
    "libretro_ppsspp/ext/libzip/zip_file_set_comment.c",
    "libretro_ppsspp/ext/libzip/zip_file_set_encryption.c",
    "libretro_ppsspp/ext/libzip/zip_file_set_external_attributes.c",
    "libretro_ppsspp/ext/libzip/zip_file_set_mtime.c",
    "libretro_ppsspp/ext/libzip/zip_file_strerror.c",
    "libretro_ppsspp/ext/libzip/zip_fopen.c",
    "libretro_ppsspp/ext/libzip/zip_fopen_encrypted.c",
    "libretro_ppsspp/ext/libzip/zip_fopen_index.c",
    "libretro_ppsspp/ext/libzip/zip_fopen_index_encrypted.c",
    "libretro_ppsspp/ext/libzip/zip_fread.c",
    "libretro_ppsspp/ext/libzip/zip_fseek.c",
    "libretro_ppsspp/ext/libzip/zip_ftell.c",
    "libretro_ppsspp/ext/libzip/zip_get_archive_comment.c",
    "libretro_ppsspp/ext/libzip/zip_get_archive_flag.c",
    "libretro_ppsspp/ext/libzip/zip_get_encryption_implementation.c",
    "libretro_ppsspp/ext/libzip/zip_get_file_comment.c",
    "libretro_ppsspp/ext/libzip/zip_get_name.c",
    "libretro_ppsspp/ext/libzip/zip_get_num_entries.c",
    "libretro_ppsspp/ext/libzip/zip_get_num_files.c",
    "libretro_ppsspp/ext/libzip/zip_hash.c",
    "libretro_ppsspp/ext/libzip/zip_io_util.c",
    "libretro_ppsspp/ext/libzip/zip_libzip_version.c",
    "libretro_ppsspp/ext/libzip/zip_memdup.c",
    "libretro_ppsspp/ext/libzip/zip_mkstempm.c",
    "libretro_ppsspp/ext/libzip/zip_name_locate.c",
    "libretro_ppsspp/ext/libzip/zip_new.c",
    "libretro_ppsspp/ext/libzip/zip_open.c",
    "libretro_ppsspp/ext/libzip/zip_pkware.c",
    "libretro_ppsspp/ext/libzip/zip_progress.c",
    "libretro_ppsspp/ext/libzip/zip_random_unix.c",
    "libretro_ppsspp/ext/libzip/zip_rename.c",
    "libretro_ppsspp/ext/libzip/zip_replace.c",
    "libretro_ppsspp/ext/libzip/zip_set_archive_comment.c",
    "libretro_ppsspp/ext/libzip/zip_set_archive_flag.c",
    "libretro_ppsspp/ext/libzip/zip_set_default_password.c",
    "libretro_ppsspp/ext/libzip/zip_set_file_comment.c",
    "libretro_ppsspp/ext/libzip/zip_set_file_compression.c",
    "libretro_ppsspp/ext/libzip/zip_set_name.c",
    "libretro_ppsspp/ext/libzip/zip_source_accept_empty.c",
    "libretro_ppsspp/ext/libzip/zip_source_begin_write.c",
    "libretro_ppsspp/ext/libzip/zip_source_begin_write_cloning.c",
    "libretro_ppsspp/ext/libzip/zip_source_buffer.c",
    "libretro_ppsspp/ext/libzip/zip_source_call.c",
    "libretro_ppsspp/ext/libzip/zip_source_close.c",
    "libretro_ppsspp/ext/libzip/zip_source_commit_write.c",
    "libretro_ppsspp/ext/libzip/zip_source_compress.c",
    "libretro_ppsspp/ext/libzip/zip_source_crc.c",
    "libretro_ppsspp/ext/libzip/zip_source_error.c",
    "libretro_ppsspp/ext/libzip/zip_source_file_common.c",
    "libretro_ppsspp/ext/libzip/zip_source_file_stdio.c",
    "libretro_ppsspp/ext/libzip/zip_source_file_stdio_named.c",
    "libretro_ppsspp/ext/libzip/zip_source_free.c",
    "libretro_ppsspp/ext/libzip/zip_source_function.c",
    "libretro_ppsspp/ext/libzip/zip_source_get_file_attributes.c",
    "libretro_ppsspp/ext/libzip/zip_source_is_deleted.c",
    "libretro_ppsspp/ext/libzip/zip_source_layered.c",
    "libretro_ppsspp/ext/libzip/zip_source_open.c",
    "libretro_ppsspp/ext/libzip/zip_source_pkware_decode.c",
    "libretro_ppsspp/ext/libzip/zip_source_pkware_encode.c",
    "libretro_ppsspp/ext/libzip/zip_source_read.c",
    "libretro_ppsspp/ext/libzip/zip_source_remove.c",
    "libretro_ppsspp/ext/libzip/zip_source_rollback_write.c",
    "libretro_ppsspp/ext/libzip/zip_source_seek.c",
    "libretro_ppsspp/ext/libzip/zip_source_seek_write.c",
    "libretro_ppsspp/ext/libzip/zip_source_stat.c",
    "libretro_ppsspp/ext/libzip/zip_source_supports.c",
    "libretro_ppsspp/ext/libzip/zip_source_tell.c",
    "libretro_ppsspp/ext/libzip/zip_source_tell_write.c",
    "libretro_ppsspp/ext/libzip/zip_source_window.c",
    "libretro_ppsspp/ext/libzip/zip_source_write.c",
    "libretro_ppsspp/ext/libzip/zip_source_zip.c",
    "libretro_ppsspp/ext/libzip/zip_source_zip_new.c",
    "libretro_ppsspp/ext/libzip/zip_stat.c",
    "libretro_ppsspp/ext/libzip/zip_stat_index.c",
    "libretro_ppsspp/ext/libzip/zip_stat_init.c",
    "libretro_ppsspp/ext/libzip/zip_strerror.c",
    "libretro_ppsspp/ext/libzip/zip_string.c",
    "libretro_ppsspp/ext/libzip/zip_unchange.c",
    "libretro_ppsspp/ext/libzip/zip_unchange_all.c",
    "libretro_ppsspp/ext/libzip/zip_unchange_archive.c",
    "libretro_ppsspp/ext/libzip/zip_unchange_data.c",
    "libretro_ppsspp/ext/libzip/zip_utf-8.c"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeLibzstdstatic = nativeTarget("PVPPSSPPlibzstdstatic", sources: [
    "libretro_ppsspp/ext/zstd/lib/common/debug.c",
    "libretro_ppsspp/ext/zstd/lib/common/entropy_common.c",
    "libretro_ppsspp/ext/zstd/lib/common/error_private.c",
    "libretro_ppsspp/ext/zstd/lib/common/fse_decompress.c",
    "libretro_ppsspp/ext/zstd/lib/common/pool.c",
    "libretro_ppsspp/ext/zstd/lib/common/threading.c",
    "libretro_ppsspp/ext/zstd/lib/common/xxhash.c",
    "libretro_ppsspp/ext/zstd/lib/common/zstd_common.c",
    "libretro_ppsspp/ext/zstd/lib/compress/fse_compress.c",
    "libretro_ppsspp/ext/zstd/lib/compress/hist.c",
    "libretro_ppsspp/ext/zstd/lib/compress/huf_compress.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_compress.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_compress_literals.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_compress_sequences.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_compress_superblock.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_double_fast.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_fast.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_lazy.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_ldm.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstd_opt.c",
    "libretro_ppsspp/ext/zstd/lib/compress/zstdmt_compress.c",
    "libretro_ppsspp/ext/zstd/lib/decompress/huf_decompress.c",
    "libretro_ppsspp/ext/zstd/lib/decompress/huf_decompress_amd64.S",
    "libretro_ppsspp/ext/zstd/lib/decompress/zstd_ddict.c",
    "libretro_ppsspp/ext/zstd/lib/decompress/zstd_decompress.c",
    "libretro_ppsspp/ext/zstd/lib/decompress/zstd_decompress_block.c",
    "libretro_ppsspp/ext/zstd/lib/dictBuilder/cover.c",
    "libretro_ppsspp/ext/zstd/lib/dictBuilder/divsufsort.c",
    "libretro_ppsspp/ext/zstd/lib/dictBuilder/fastcover.c",
    "libretro_ppsspp/ext/zstd/lib/dictBuilder/zdict.c"
], defines: [
    "ZSTD_MULTITHREAD",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "XXH_NAMESPACE=ZSTD_",
    "ZSTD_LEGACY_SUPPORT=0"
], headers: [
    "cmake/ext/zstd/build/cmake/lib",
    "libretro_ppsspp/ext/zstd/build/cmake/lib",
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/build/cmake/../../lib",
    "libretro_ppsspp/ext/zstd/build/cmake/../../lib/common"
])

let nativeMiniupnpc = nativeTarget("PVPPSSPPminiupnpc", sources: [
    "libretro_ppsspp/ext/miniupnp/miniupnpc/addr_is_reserved.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/connecthostport.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/igd_desc_parse.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/minisoap.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/minissdpc.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/miniupnpc.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/miniwget.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/minixml.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/minixmlvalid.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/portlistingparse.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/receivedata.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/upnpcommands.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/upnpdev.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/upnperrors.c",
    "libretro_ppsspp/ext/miniupnp/miniupnpc/upnpreplyparse.c"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeNative = nativeTarget("PVPPSSPPnative", sources: [
    "PVPPSSPPCore/Core/AppleBatteryClient.m",
    "libretro_ppsspp/Common/Render/Text/draw_text_qt.cpp",
    "libretro_ppsspp/UI/AudioCommon.cpp",
    "libretro_ppsspp/UI/BackgroundAudio.cpp",
    "libretro_ppsspp/UI/ChatScreen.cpp",
    "libretro_ppsspp/UI/ControlMappingScreen.cpp",
    "libretro_ppsspp/UI/CustomButtonMappingScreen.cpp",
    "libretro_ppsspp/UI/CwCheatScreen.cpp",
    "libretro_ppsspp/UI/DevScreens.cpp",
    "libretro_ppsspp/UI/DiscordIntegration.cpp",
    "libretro_ppsspp/UI/DisplayLayoutScreen.cpp",
    "libretro_ppsspp/UI/EmuScreen.cpp",
    "libretro_ppsspp/UI/GPUDriverTestScreen.cpp",
    "libretro_ppsspp/UI/GameInfoCache.cpp",
    "libretro_ppsspp/UI/GameScreen.cpp",
    "libretro_ppsspp/UI/GameSettingsScreen.cpp",
    "libretro_ppsspp/UI/GamepadEmu.cpp",
    "libretro_ppsspp/UI/InstallZipScreen.cpp",
    "libretro_ppsspp/UI/JoystickHistoryView.cpp",
    "libretro_ppsspp/UI/MainScreen.cpp",
    "libretro_ppsspp/UI/MemStickScreen.cpp",
    "libretro_ppsspp/UI/MiscScreens.cpp",
    "libretro_ppsspp/UI/NativeApp.cpp",
    "libretro_ppsspp/UI/OnScreenDisplay.cpp",
    "libretro_ppsspp/UI/PauseScreen.cpp",
    "libretro_ppsspp/UI/ProfilerDraw.cpp",
    "libretro_ppsspp/UI/RemoteISOScreen.cpp",
    "libretro_ppsspp/UI/ReportScreen.cpp",
    "libretro_ppsspp/UI/SavedataScreen.cpp",
    "libretro_ppsspp/UI/Store.cpp",
    "libretro_ppsspp/UI/Theme.cpp",
    "libretro_ppsspp/UI/TiltAnalogSettingsScreen.cpp",
    "libretro_ppsspp/UI/TouchControlLayoutScreen.cpp",
    "libretro_ppsspp/UI/TouchControlVisibilityScreen.cpp",
    "libretro_ppsspp/android/jni/TestRunner.cpp",
    "libretro_ppsspp/ext/jpge/jpgd.cpp",
    "libretro_ppsspp/ext/jpge/jpge.cpp",
    "libretro_ppsspp/ios/SmartKeyboardMap.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB",
    "STACK_LINE_READER_BUFFER_SIZE=1024"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake",
    "libretro_ppsspp/ext/snappy/.",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include",
    "libretro_ppsspp/Common/Battery"
])

let nativePng17 = nativeTarget("PVPPSSPPpng17", sources: [
    "libretro_ppsspp/ext/libpng17/arm/arm_init.c",
    "libretro_ppsspp/ext/libpng17/arm/filter_neon_intrinsics.c",
    "libretro_ppsspp/ext/libpng17/png.c",
    "libretro_ppsspp/ext/libpng17/pngerror.c",
    "libretro_ppsspp/ext/libpng17/pngget.c",
    "libretro_ppsspp/ext/libpng17/pngmem.c",
    "libretro_ppsspp/ext/libpng17/pngpread.c",
    "libretro_ppsspp/ext/libpng17/pngread.c",
    "libretro_ppsspp/ext/libpng17/pngrio.c",
    "libretro_ppsspp/ext/libpng17/pngrtran.c",
    "libretro_ppsspp/ext/libpng17/pngrutil.c",
    "libretro_ppsspp/ext/libpng17/pngset.c",
    "libretro_ppsspp/ext/libpng17/pngtrans.c",
    "libretro_ppsspp/ext/libpng17/pngwio.c",
    "libretro_ppsspp/ext/libpng17/pngwrite.c",
    "libretro_ppsspp/ext/libpng17/pngwtran.c",
    "libretro_ppsspp/ext/libpng17/pngwutil.c"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeSfmt19937 = nativeTarget("PVPPSSPPsfmt19937", sources: [
    "libretro_ppsspp/ext/sfmt19937/SFMT.c"
], defines: [
    "SFMT_MEXP=19937",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/sfmt19937",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeSnappy = nativeTarget("PVPPSSPPsnappy", sources: [
    "libretro_ppsspp/ext/snappy/snappy-c.cpp",
    "libretro_ppsspp/ext/snappy/snappy-sinksource.cpp",
    "libretro_ppsspp/ext/snappy/snappy-stubs-internal.cpp",
    "libretro_ppsspp/ext/snappy/snappy.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/snappy/."
])

let nativeSpirvcrosscore = nativeTarget("PVPPSSPPspirvcrosscore", sources: [
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_cfg.cpp",
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_cross.cpp",
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_cross_parsed_ir.cpp",
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_cross_util.cpp",
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_parser.cpp"
], defines: [
    "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
    "__STDC_LIMIT_MACROS",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/SPIRV-Cross-build/../SPIRV-Cross"
])

let nativeSpirvcrosscpp = nativeTarget("PVPPSSPPspirvcrosscpp", sources: [
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_cpp.cpp"
], defines: [
    "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
    "__STDC_LIMIT_MACROS",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/SPIRV-Cross-build/../SPIRV-Cross"
])

let nativeSpirvcrossglsl = nativeTarget("PVPPSSPPspirvcrossglsl", sources: [
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_glsl.cpp"
], defines: [
    "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
    "__STDC_LIMIT_MACROS",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/SPIRV-Cross-build/../SPIRV-Cross"
])

let nativeSpirvcrosshlsl = nativeTarget("PVPPSSPPspirvcrosshlsl", sources: [
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_hlsl.cpp"
], defines: [
    "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
    "__STDC_LIMIT_MACROS",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/SPIRV-Cross-build/../SPIRV-Cross"
])

let nativeSpirvcrossmsl = nativeTarget("PVPPSSPPspirvcrossmsl", sources: [
    "libretro_ppsspp/ext/SPIRV-Cross/spirv_msl.cpp"
], defines: [
    "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
    "__STDC_LIMIT_MACROS",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/SPIRV-Cross-build/../SPIRV-Cross"
])

let nativeUdis86 = nativeTarget("PVPPSSPPudis86", sources: [
    "libretro_ppsspp/ext/udis86/decode.c",
    "libretro_ppsspp/ext/udis86/itab.c",
    "libretro_ppsspp/ext/udis86/syn-att.c",
    "libretro_ppsspp/ext/udis86/syn-intel.c",
    "libretro_ppsspp/ext/udis86/syn.c",
    "libretro_ppsspp/ext/udis86/udis86.c"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp"
])

let nativeUnixbasedhardwaredetection = nativeTarget("PVPPSSPPunixbasedhardwaredetection", sources: [
    "libretro_ppsspp/ext/cpu_features/src/hwcaps.c"
], defines: [
    "STACK_LINE_READER_BUFFER_SIZE=1024",
    "HAVE_DLFCN_H",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include/internal"
])

let nativeUtils = nativeTarget("PVPPSSPPutils", sources: [
    "libretro_ppsspp/ext/cpu_features/src/filesystem.c",
    "libretro_ppsspp/ext/cpu_features/src/stack_line_reader.c",
    "libretro_ppsspp/ext/cpu_features/src/string_view.c"
], defines: [
    "STACK_LINE_READER_BUFFER_SIZE=1024",
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include",
    "libretro_ppsspp/ext/cmake/cpu_features/../../cpu_features/include/internal"
])

let nativeVma = nativeTarget("PVPPSSPPvma", sources: [
    "libretro_ppsspp/ext/vma/vk_mem_alloc.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeXbrz = nativeTarget("PVPPSSPPxbrz", sources: [
    "libretro_ppsspp/ext/xbrz/xbrz.cpp"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/xbrz",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeXxhash = nativeTarget("PVPPSSPPxxhash", sources: [
    "libretro_ppsspp/ext/xxhash.c"
], defines: [
    "GL_ETC1_RGB8_OES=0",
    "__STDC_CONSTANT_MACROS",
    "USING_GLES2",
    "MOBILE_DEVICE",
    "PNG_ARM_NEON_OPT=0",
    "SHARED_ZLIB",
    "MINIUPNPC_SET_SOCKET_TIMEOUT",
    "_BSD_SOURCE",
    "_DEFAULT_SOURCE",
    "_POSIX_C_SOURCE=200112L",
    "_DARWIN_C_SOURCE",
    "WITH_UPNP",
    "MINIUPNP_STATICLIB"
], headers: [
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glew",
    "libretro_ppsspp",
    "libretro_ppsspp/ext/openxr",
    "libretro_ppsspp/Common",
    "libretro_ppsspp/ext/libzip",
    "libretro_ppsspp/ext/libpng17",
    "libretro_ppsspp/ext/zstd/lib",
    "cmake"
])

let nativeGlslangOverrides = nativeTarget("PVPPSSPPGlslangOverrides", sources: [
    "PVPPSSPPCore/ppsspp/glslang/GlslangToSpvPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/ShaderLang.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/intermOut.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/propagateNoContraction.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/ParseHelper.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/iomapper.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/parseConst.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/SpirvIntrinsics.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/PoolAlloc.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/preprocessor/PpTokens.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/ParseContextBase.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/preprocessor/PpScanner.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/Initialize.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/glslang_tab.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/IntermTraverse.cpp",
    "PVPPSSPPCore/ppsspp/glslang/docPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/InfoSink.cpp",
    "PVPPSSPPCore/ppsspp/glslang/SpvPostProcessPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/Intermediate.cpp",
    "PVPPSSPPCore/ppsspp/glslang/disassemblePPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/reflection.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/RemoveTree.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/Scan.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/attribute.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/Constant.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/preprocessor/Pp.cpp",
    "PVPPSSPPCore/ppsspp/glslang/SpvBuilderPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/InReadableOrderPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/linkValidate.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/Versions.cpp",
    "PVPPSSPPCore/ppsspp/glslang/SpvToolsPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/limits.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/preprocessor/PpContext.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/preprocessor/PpAtom.cpp",
    "PVPPSSPPCore/ppsspp/glslang/SPVRemapperPPSSPP.cpp",
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent/SymbolTable.cpp",
    "PVPPSSPPCore/ppsspp/glslang/LoggerPPSSPP.cpp"
], defines: [
    "ENABLE_HLSL",
    "GLSLANG_OSINCLUDE_UNIX",
    "ENABLE_OPT=0"
], headers: [
    "PVPPSSPPCore/ppsspp/glslang/MachineIndependent",
    "PVPPSSPPCore/ppsspp/glslang",
    "PVPPSSPPCore/ppsspp",
    "libretro_ppsspp/ext/glslang/SPIRV",
    "libretro_ppsspp/ext/glslang",
    "libretro_ppsspp/ext/glslang/glslang",
    "libretro_ppsspp/ext/glslang/glslang/MachineIndependent",
    "cmake/include"
])

let swiftSources = [
    "PVPPSSPPCore/Core/CorePlist-Generated.swift",
    "PVPPSSPPCore/Core/CorePlist.swift",
    "PVPPSSPPCore/Core/PVPPSSPPCore.swift",
    "PVPPSSPPCore/Core/PPSSPPVulkanViewController.swift",
    "PVPPSSPPCore/Core/CoreOptions.swift",
    "PVPPSSPPCore/Core/PPSSPPOGLViewController.swift",
    "PVPPSSPPCore/Core/PVPPSSPPCore+PVNetplayCapable.swift",
    "PVPPSSPPCore/Core/PVPPSSPPCore+RetroAchievements.swift"
]
let bridgeSources = [
    "PVPPSSPPCore/Core/MemArenaDarwin.cpp",
    "PVPPSSPPCore/Core/PVPPSSPPCore+Cheats.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore+Controls.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore+Video.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore+Saves.mm",
    "PVPPSSPPCore/Core/iOSCoreAudio.mm",
    "PVPPSSPPCore/PVPPSSPP.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore.mm",
    "PVPPSSPPCore/Core/DarwinFileSystemServices.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore+Audio.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore+Netplay.mm",
    "PVPPSSPPCore/Core/PVPPSSPPCore+RetroAchievements.mm"
]

let nativeTargets: [Target] = [
    nativeCommon,
    nativeCore,
    nativeGenericCodeGen,
    nativeHLSL,
    nativeMachineIndependent,
    nativeOGLCompiler,
    nativeOSDependent,
    nativeSPIRV,
    nativeArmips,
    nativeBasisuniversal,
    nativeCityhash,
    nativeGason,
    nativeGlslang,
    nativeGlslangdefaultresourcelimits,
    nativeKirk,
    nativeLibzip,
    nativeLibzstdstatic,
    nativeMiniupnpc,
    nativeNative,
    nativePng17,
    nativeSfmt19937,
    nativeSnappy,
    nativeSpirvcrosscore,
    nativeSpirvcrosscpp,
    nativeSpirvcrossglsl,
    nativeSpirvcrosshlsl,
    nativeSpirvcrossmsl,
    nativeUdis86,
    nativeUnixbasedhardwaredetection,
    nativeUtils,
    nativeVma,
    nativeXbrz,
    nativeXxhash,
    nativeGlslangOverrides
]
let nativeDependencies: [Target.Dependency] = [
    "PVPPSSPPCommon",
    "PVPPSSPPCore",
    "PVPPSSPPGenericCodeGen",
    "PVPPSSPPHLSL",
    "PVPPSSPPMachineIndependent",
    "PVPPSSPPOGLCompiler",
    "PVPPSSPPOSDependent",
    "PVPPSSPPSPIRV",
    "PVPPSSPParmips",
    "PVPPSSPPbasisuniversal",
    "PVPPSSPPcityhash",
    "PVPPSSPPgason",
    "PVPPSSPPglslang",
    "PVPPSSPPglslangdefaultresourcelimits",
    "PVPPSSPPkirk",
    "PVPPSSPPlibzip",
    "PVPPSSPPlibzstdstatic",
    "PVPPSSPPminiupnpc",
    "PVPPSSPPnative",
    "PVPPSSPPpng17",
    "PVPPSSPPsfmt19937",
    "PVPPSSPPsnappy",
    "PVPPSSPPspirvcrosscore",
    "PVPPSSPPspirvcrosscpp",
    "PVPPSSPPspirvcrossglsl",
    "PVPPSSPPspirvcrosshlsl",
    "PVPPSSPPspirvcrossmsl",
    "PVPPSSPPudis86",
    "PVPPSSPPunixbasedhardwaredetection",
    "PVPPSSPPutils",
    "PVPPSSPPvma",
    "PVPPSSPPxbrz",
    "PVPPSSPPxxhash",
    "PVPPSSPPGlslangOverrides"
]
let modules = [
    "PVAudio",
    "PVCoreBridge",
    "PVCoreObjCBridge",
    "PVEmulatorCore",
    "PVLogging",
    "PVPlists",
    "PVPrimitives",
    "PVSettings",
    "PVShaders",
    "PVSupport",
    "PVNetplay",
    "PVRcheevos",
    "PVRcheevosBridge"
]
let dependencies: [Package.Dependency] = modules.map { .package(path: "../../" + $0) } + [
    .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2")
]
let shared: [Target.Dependency] = modules.map { .product(name: $0, package: $0) }
// SwiftPM selects the Mach-O platform slice, including arm64 Apple simulators.
let ffmpeg = Target.binaryTarget(name: "PPSSPPFFmpeg", path: "SwiftPM/FFmpeg/PPSSPPFFmpeg.xcframework")
// Keep shader compiler definitions local when Azahar, Dolphin and PPSSPP share an app.
let imageFlags = [
    "-ObjC",
    "-unexported_symbol", "_PVPPSSPP_md5*",
    "-unexported_symbol", "_glslang*", "-unexported_symbol", "_SPIRV*",
    "-unexported_symbol", "_TBuiltInResource*", "-unexported_symbol", "_EShLanguage*",
    "-unexported_symbol", "__ZN7glslang*", "-unexported_symbol", "__ZN5SPIRV*",
    "-unexported_symbol", "__ZN4spv*", "-unexported_symbol", "__Z*glslang*",
    "-unexported_symbol", "__Z*SPIRV*", "-unexported_symbol", "__Z*spv*"
].flatMap { ["-Xlinker", $0] }

let frameworks = [
    "GLKit",
    "UIKit",
    "QuartzCore",
    "CoreHaptics",
    "AVFoundation",
    "CoreAudio",
    "AudioToolbox",
    "MetalKit",
    "CoreGraphics",
    "SystemConfiguration",
    "Foundation",
    "Metal",
    "Security",
    "OpenGLES",
    "GameController"
]
let linkerSettings: [LinkerSetting] = frameworks.map { .linkedFramework($0) } + [
    .linkedFramework("CoreAudioKit", .when(platforms: [.iOS])),
    .linkedFramework("CoreMotion", .when(platforms: [.iOS])),
    .linkedLibrary("c++"), .linkedLibrary("z"), .linkedLibrary("bz2"), .linkedLibrary("sqlite3"), .linkedLibrary("iconv"), .unsafeFlags(imageFlags)
]
let bridge = Target.target(name: "PVPPSSPPBridge", dependencies: shared + nativeDependencies + ["PPSSPPFFmpeg"], path: ".",
                           exclude: exclusions(for: bridgeSources, resources: ["cmake/assets"]), sources: bridgeSources,
                           resources: [.copy("cmake/assets")], publicHeadersPath: "SwiftPM/Bridge/include",
                           cSettings: [.unsafeFlags(ffmpegHeaderFlags + nativeHeaders.flatMap { ["-I", root + "/" + $0] } + commonFlags)],
                           cxxSettings: [.unsafeFlags(ffmpegHeaderFlags + nativeHeaders.flatMap { ["-I", root + "/" + $0] } + commonFlags + ["-fmodules", "-fcxx-modules"])],
                           linkerSettings: linkerSettings)
let core = Target.target(name: "PVPPSSPP", dependencies: shared + ["PVPPSSPPBridge", .product(name: "Defaults", package: "Defaults")], path: ".",
                         exclude: exclusions(for: swiftSources, resources: ["PVPPSSPP/Core.plist"]), sources: swiftSources,
                         resources: [.process("PVPPSSPP/Core.plist")])
let package = Package(name: "PVCorePPSSPP", platforms: [.iOS(.v17), .tvOS(.v17)],
                      products: [.library(name: "PVPPSSPP", targets: ["PVPPSSPP"]), .library(name: "PVPPSSPP-Dynamic", type: .dynamic, targets: ["PVPPSSPP"])],
                      dependencies: dependencies, targets: nativeTargets + [ffmpeg, bridge, core], swiftLanguageModes: [.v5], cLanguageStandard: .gnu11, cxxLanguageStandard: .gnucxx17)
