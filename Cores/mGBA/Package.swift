// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Compile settings for the mGBA core. Upstream master no longer has an
/// OpenEmu target; this follows its libretro embed (DISABLE_THREADING,
/// MGBA_STANDALONE, ENABLE_VFS) plus the POSIX ENABLE_VFS_FD, the
/// ENABLE_DIRECTORIES that ENABLE_VFS turns on (save directory and
/// mCoreAutoloadSave), MINIMAL_CORE=1 as the previous build used, and the
/// Apple FUNCTION_DEFINES its configure step finds. The bridge uses the same
/// set so mGBA's structs have the same layout on both sides.
let libmGBACSettings: [PackageDescription.CSetting] = [
    .define("M_CORE_GBA", to: "1"),
    .define("M_CORE_GB", to: "1"),
    .define("MINIMAL_CORE", to: "1"),
    .define("DISABLE_THREADING", to: "1"),
    .define("MGBA_STANDALONE", to: "1"),
    .define("_DARWIN_C_SOURCE", to: "1"),

    .define("ENABLE_VFS", to: "1"),
    .define("ENABLE_VFS_FD", to: "1"),
    .define("ENABLE_DIRECTORIES", to: "1"),

    .define("HAVE_FUTIMENS", to: "1"),
    .define("HAVE_FUTIMES", to: "1"),
    .define("HAVE_LOCALE", to: "1"),
    .define("HAVE_LOCALTIME_R", to: "1"),
    .define("HAVE_REALPATH", to: "1"),
    .define("HAVE_SETLOCALE", to: "1"),
    .define("HAVE_SNPRINTF_L", to: "1"),
    .define("HAVE_STRDUP", to: "1"),
    .define("HAVE_STRLCPY", to: "1"),
    .define("HAVE_STRNDUP", to: "1"),
    .define("HAVE_STRTOF_L", to: "1"),
    .define("HAVE_USELOCALE", to: "1"),
    .define("HAVE_VASPRINTF", to: "1"),
    .define("HAVE_XLOCALE", to: "1"),
]

/// Paths are relative to the target directory that uses them.
let libmGBAHeaderSearchPaths: [PackageDescription.CSetting] = [
    .headerSearchPath("mgba/include"),
    .headerSearchPath("mgba/src"),
]

/// The `CORE_SRC` + `VFS_SRC` file set upstream's CMake builds on Apple with
/// MINIMAL_CORE and ENABLE_VFS, from mgba/CMakeLists.txt and
/// src/{core,arm,gba,gb,sm83,util}/CMakeLists.txt at master c3c8e5e813.
/// Not built: debuggers, scripting, SIO lockstep/dolphin, extras, GUI,
/// the libretro/Qt/SDL frontends, and the zlib/libpng/lzma/sqlite3 deps
/// (no zip/7z ROM loading, no PNG screenshots, no game database).
let libmGBASources: [String] = [
    // Provenance replacement for the CMake-generated version.c
    "version.c",

    // src/core (library.c is built with ENABLE_VFS)
    "mgba/src/core/bitmap-cache.c",
    "mgba/src/core/cache-set.c",
    "mgba/src/core/cheats.c",
    "mgba/src/core/config.c",
    "mgba/src/core/core.c",
    "mgba/src/core/directories.c",
    "mgba/src/core/input.c",
    "mgba/src/core/interface.c",
    "mgba/src/core/library.c",
    "mgba/src/core/lockstep.c",
    "mgba/src/core/log.c",
    "mgba/src/core/map-cache.c",
    "mgba/src/core/mem-search.c",
    "mgba/src/core/rewind.c",
    "mgba/src/core/serialize.c",
    "mgba/src/core/sync.c",
    "mgba/src/core/thread.c",
    "mgba/src/core/tile-cache.c",
    "mgba/src/core/timing.c",

    // src/arm
    "mgba/src/arm/arm.c",
    "mgba/src/arm/decoder-arm.c",
    "mgba/src/arm/decoder.c",
    "mgba/src/arm/decoder-thumb.c",
    "mgba/src/arm/isa-arm.c",
    "mgba/src/arm/isa-thumb.c",

    // src/gba
    "mgba/src/gba/audio.c",
    "mgba/src/gba/bios.c",
    "mgba/src/gba/cart/ereader.c",
    "mgba/src/gba/cart/gpio.c",
    "mgba/src/gba/cart/matrix.c",
    "mgba/src/gba/cart/unlicensed.c",
    "mgba/src/gba/cart/vfame.c",
    "mgba/src/gba/cheats.c",
    "mgba/src/gba/cheats/codebreaker.c",
    "mgba/src/gba/cheats/gameshark.c",
    "mgba/src/gba/cheats/parv3.c",
    "mgba/src/gba/core.c",
    "mgba/src/gba/dma.c",
    "mgba/src/gba/gba.c",
    "mgba/src/gba/hle-bios.c",
    "mgba/src/gba/input.c",
    "mgba/src/gba/io.c",
    "mgba/src/gba/memory.c",
    "mgba/src/gba/overrides.c",
    "mgba/src/gba/renderers/cache-set.c",
    "mgba/src/gba/renderers/common.c",
    "mgba/src/gba/renderers/gl.c",
    "mgba/src/gba/renderers/software-bg.c",
    "mgba/src/gba/renderers/software-mode0.c",
    "mgba/src/gba/renderers/software-obj.c",
    "mgba/src/gba/renderers/video-software.c",
    "mgba/src/gba/savedata.c",
    "mgba/src/gba/serialize.c",
    "mgba/src/gba/sharkport.c",
    "mgba/src/gba/sio.c",
    "mgba/src/gba/sio/gbp.c",
    "mgba/src/gba/timer.c",
    "mgba/src/gba/video.c",

    // src/gb (the GBA core also uses gb/audio.c)
    "mgba/src/gb/audio.c",
    "mgba/src/gb/cheats.c",
    "mgba/src/gb/core.c",
    "mgba/src/gb/gb.c",
    "mgba/src/gb/input.c",
    "mgba/src/gb/io.c",
    "mgba/src/gb/mbc.c",
    "mgba/src/gb/mbc/huc-3.c",
    "mgba/src/gb/mbc/licensed.c",
    "mgba/src/gb/mbc/mbc.c",
    "mgba/src/gb/mbc/pocket-cam.c",
    "mgba/src/gb/mbc/tama5.c",
    "mgba/src/gb/mbc/unlicensed.c",
    "mgba/src/gb/memory.c",
    "mgba/src/gb/overrides.c",
    "mgba/src/gb/renderers/cache-set.c",
    "mgba/src/gb/renderers/software.c",
    "mgba/src/gb/serialize.c",
    "mgba/src/gb/sio.c",
    "mgba/src/gb/timer.c",
    "mgba/src/gb/video.c",

    // src/sm83
    "mgba/src/sm83/decoder.c",
    "mgba/src/sm83/isa-sm83.c",
    "mgba/src/sm83/sm83.c",

    // src/util
    "mgba/src/util/audio-buffer.c",
    "mgba/src/util/audio-resampler.c",
    "mgba/src/util/circle-buffer.c",
    "mgba/src/util/configuration.c",
    "mgba/src/util/convolve.c",
    "mgba/src/util/crc32.c",
    "mgba/src/util/elf-read.c",
    "mgba/src/util/formatting.c",
    "mgba/src/util/gbk-table.c",
    "mgba/src/util/geometry.c",
    "mgba/src/util/hash.c",
    "mgba/src/util/image.c",
    "mgba/src/util/image/export.c",
    "mgba/src/util/image/font.c",
    "mgba/src/util/image/png-io.c",
    "mgba/src/util/interpolator.c",
    "mgba/src/util/md5.c",
    "mgba/src/util/patch.c",
    "mgba/src/util/patch-fast.c",
    "mgba/src/util/patch-ips.c",
    "mgba/src/util/patch-ups.c",
    "mgba/src/util/ring-fifo.c",
    "mgba/src/util/sfo.c",
    "mgba/src/util/sha1.c",
    "mgba/src/util/string.c",
    "mgba/src/util/table.c",
    "mgba/src/util/text-codec.c",
    "mgba/src/util/vector.c",
    "mgba/src/util/vfs.c",

    // CORE_VFS_SRC + VFS_SRC (POSIX)
    "mgba/src/util/vfs/vfs-dirent.c",
    "mgba/src/util/vfs/vfs-fd.c",
    "mgba/src/util/vfs/vfs-fifo.c",
    "mgba/src/util/vfs/vfs-mem.c",

    // OS_SRC (POSIX) and THIRD_PARTY_SRC
    "mgba/src/platform/posix/memory.c",
    "mgba/src/third-party/inih/ini.c",
]

let package = Package(
    name: "PVCoremGBA",
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
        .package(name: "PVPrimitives", path: "../../PVPrimitives/"),
        .package(path: "../../PVNetplay"),
        .package(path: "../../PVPatching"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),
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
                "PVPrimitives",
                "PVNetplay",
                "PVPatching",
                "libmGBA",
                "PVmGBABridge",
                .product(name: "PVRcheevos", package: "PVRcheevos"),
                .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
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
                .headerSearchPath("../libmGBA-embed/mgba/include"),
                .headerSearchPath("../libmGBA-embed/mgba/src")]),
        // MARK: ============ mGBA =============
        // mGBA itself comes from the `mgba` submodule (Provenance-Emu/mgba,
        // branch Provenance-master, which tracks upstream master). Only the module map and version.c beside
        // it are Provenance files.
        .target(
            name: "libmGBA",
            path: "Sources/libmGBA-embed",
            sources: libmGBASources,
            publicHeadersPath: "include",
            packageAccess: true,
            cSettings: libmGBACSettings + libmGBAHeaderSearchPaths)
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
