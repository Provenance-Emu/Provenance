// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let libmGBACSettings: [PackageDescription.CSetting] = [
    .define("INLINE", to: "inline"),

    .define("DISABLE_THREADING", to: "1"), // TODO: Test with this
    .define("HAVE_LOCALE", to: "1"),
    .define("HAVE_LOCALTIME_R", to: "1"),
    .define("HAVE_SNPRINTF_L", to: "1"),
    .define("HAVE_STRDUP", to: "1"),
    .define("HAVE_STRLCPY", to: "1"),
    .define("HAVE_STRNDUP", to: "1"),
    .define("HAVE_STRTOF_L", to: "1"),
    .define("HAVE_XLOCALE", to: "1"),
    .define("MGBA_STANDALONE", to: "1"),
    .define("MINIMAL_CORE", to: "1"),
    .define("M_CORE_GBA", to: "1"),
    .define("M_CORE_GB", to: "1"),
    
    .define("ENABLE_VFS", to: "1"),
    .define("ENABLE_VFS_FD", to: "1"),
//    .define("ENABLE_VFS_FILE", to: "1"),

    // Fix weird underflow/overflow issues
    
    .define("_SIZE_T", to: "int"),
    .define("size_t", to: "int"),
]

let package = Package(
    name: "PVCoremGBA",
    platforms: [
        .iOS(.v17),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v10_13),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVCoremGBA",
            targets: ["PVmGBACore"]),
        .library(
            name: "PVCoremGBA-Dynamic",
            type: .dynamic,
            targets: ["PVmGBACore"]),
        .library(
            name: "PVCoremGBA-Static",
            type: .static,
            targets: ["PVmGBACore"]),
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
        // MARK: ============ Core =============
        .target(
            name: "PVmGBACore",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVCoreObjCBridge",
                "PVPlists",
                "libmGBA",
                "PVmGBABridge"
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")]),
        // MARK: ============ Bridge =============
        .target(
            name: "PVmGBABridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVObjCUtils",
                "libmGBA"
            ],
            publicHeadersPath: "include",
            cSettings: libmGBACSettings + [
                .headerSearchPath("../libmGBA/include"),
                .headerSearchPath("../libmGBA/src")]),
        // MARK: ============ Core =============
        .target(
            name: "libmGBA",
            exclude: [
                "en.lproj",
                "src/arm/debugger/",
                "src/core/test/",
                "src/core/scripting.c",
                "src/debugger/",
                "src/feature/",
                "src/gb/debugger/",
                "src/gb/extra/",
                "src/gb/test/",
                "src/gba/debugger/",
                "src/gba/extra/",
                "src/gba/test/",
                "src/gba/hle-bios.s",
                "src/platform/",
                "src/script/",
                "src/sm83/debugger/",
                "src/third-party/discord-rpc/",
//                "src/third-party/inih/",
                "src/third-party/libpng/",
                "src/third-party/lzma/",
                "src/third-party/sqlite3/",
                "src/third-party/zlib/",
                "src/tools/",
                "src/util/gui/",
                "src/util/test/",
                "src/util/vfs/vfs-devlist.c",
//                "src/util/vfs/",
//                "src/util/vfs/vfs-fd.c",
                "src/util/vfs/vfs-file.c",
                "src/util/vfs/vfs-zip.c",
            ],
            sources: mGBASources,
            publicHeadersPath: "module",
            packageAccess: true,
            cSettings:
                libmGBACSettings + [
                .headerSearchPath("./include"),
                .headerSearchPath("./src")])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx14
)

let mGBASources: [String] = [
        "src/arm/arm.c",
        "src/arm/decoder-arm.c",
        "src/arm/decoder-thumb.c",
        "src/arm/decoder.c",
        "src/arm/isa-arm.c",
        "src/arm/isa-thumb.c",
        "src/core/bitmap-cache.c",
        "src/core/cache-set.c",
        "src/core/cheats.c",
        "src/core/config.c",
        "src/core/core.c",
        "src/core/directories.c",
        "src/core/input.c",
        "src/core/interface.c",
        "src/core/library.c",
        "src/core/lockstep.c",
        "src/core/log.c",
        "src/core/map-cache.c",
        "src/core/mem-search.c",
        "src/core/rewind.c",
        "src/core/serialize.c",
        "src/core/sync.c",
        "src/core/thread.c",
        "src/core/tile-cache.c",
        "src/core/timing.c",
        "src/gba/audio.c",
        "src/gba/bios.c",
        "src/gba/cheats/codebreaker.c",
        "src/gba/cheats/gameshark.c",
        "src/gba/cheats/parv3.c",
        "src/gba/cheats.c",
        "src/gba/core.c",
        "src/gba/dma.c",
        "src/gba/gba.c",
        "src/gba/hle-bios.c",
        "src/gba/input.c",
        "src/gba/io.c",
        "src/gba/memory.c",
        "src/gba/overrides.c",
        "src/gba/renderers/cache-set.c",
        "src/gba/renderers/common.c",
        "src/gba/renderers/software-bg.c",
        "src/gba/renderers/software-mode0.c",
        "src/gba/renderers/software-obj.c",
        "src/gba/renderers/video-software.c",
        "src/gba/savedata.c",
        "src/gba/serialize.c",
        "src/gba/sharkport.c",
        "src/gba/sio.c",
        "src/gba/sio/lockstep.c",
        "src/gba/timer.c",
        "src/gba/video.c",
        "src/platform/posix/memory.c",
        "src/third-party/blip_buf/blip_buf.c",
        "src/third-party/inih/ini.c",
        "src/util/circle-buffer.c",
        "src/util/configuration.c",
        "src/util/crc32.c",
        "src/util/formatting.c",
        "src/util/gbk-table.c",
        "src/util/hash.c",
        "src/util/patch-ips.c",
        "src/util/patch-fast.c",
        "src/util/patch-ups.c",
        "src/util/patch.c",
        "src/util/string.c",
        "src/util/table.c",
        "src/util/text-codec.c",
        "src/util/vfs.c",
        "src/util/vfs/vfs-dirent.c",
        "src/util/vfs/vfs-fd.c",
        "src/util/vfs/vfs-fifo.c",
        "src/util/vfs/vfs-mem.c",
    ]
/*
 
 mGBA files:
 
 src/arm/arm.c
 src/arm/decoder-arm.c
 src/arm/decoder-thumb.c
 src/arm/decoder.c
 src/arm/isa-arm.c
 src/arm/isa-thumb.c
 src/core/bitmap-cache.c
 src/core/cache-set.c
 src/core/cheats.c
 src/core/config.c
 src/core/core.c
 src/core/directories.c
 src/core/input.c
 src/core/interface.c
 src/core/library.c
 src/core/lockstep.c
 src/core/log.c
 src/core/map-cache.c
 src/core/mem-search.c
 src/core/rewind.c
 src/core/serialize.c
 src/core/sync.c
 src/core/thread.c
 src/core/tile-cache.c
 src/core/timing.c
 src/gb/audio.c
 src/gba/audio.c
 src/gba/bios.c
 src/gba/cheats.c
 src/gba/cheats/codebreaker.c
 src/gba/cheats/gameshark.c
 src/gba/cheats/parv3.c
 src/gba/core.c
 src/gba/dma.c
 src/gba/ereader.c
 src/gba/gba.c
 src/gba/hardware.c
 src/gba/hle-bios.c
 src/gba/input.c
 src/gba/io.c
 src/gba/matrix.c
 src/gba/memory.c
 src/gba/overrides.c
 src/gba/renderers/cache-set.c
 src/gba/renderers/common.c
 src/gba/renderers/software-bg.c
 src/gba/renderers/software-mode0.c
 src/gba/renderers/software-obj.c
 src/gba/renderers/video-software.c
 src/gba/savedata.c
 src/gba/serialize.c
 src/gba/sio.c
 src/gba/sio/lockstep.c
 src/gba/timer.c
 src/gba/vfame.c
 src/gba/video.c
 src/platform/openemu/mGBAGameCore.m
 src/platform/posix/memory.c
 src/third-party/blip_buf/blip_buf.c
 src/third-party/inih/ini.c
 src/util/circle-buffer.c
 src/util/configuration.c
 src/util/crc32.c
 src/util/export.c
 src/util/formatting.c
 src/util/gbk-table.c
 src/util/hash.c
 src/util/patch-ips.c
 src/util/patch-ups.c
 src/util/patch.c
 src/util/string.c
 src/util/table.c
 src/util/text-codec.c
 src/util/vfs.c
 src/util/vfs/vfs-dirent.c
 src/util/vfs/vfs-fd.c
 src/util/vfs/vfs-fifo.c
 src/util/vfs/vfs-mem.c
 
 
 Build & Install mGBA files:
 
 
 */
