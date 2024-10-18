// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 This package won't build yet
 
 TODO:
 - Filesystem driver; see _splitpath and _makepath
 - Audio driver?
 - Video?
 - Controllers
 */

import PackageDescription

enum Sources {
    static let libSNESticle: [String] = [
        "sncpu.c",
        "sncpu_c.c",
        "sndebug.cpp",
        "sndisasm.c",
        "sndma.cpp",
        "sndsp1.cpp",
        "snes.cpp",
        "snesreg.cpp",
        "snio.cpp",
        "snmemmap.cpp",
        "snppu.cpp",
        "snppubg.cpp",
        "snppublend_c.cpp",
        "snppucolor.cpp",
        "snppuobj.cpp",
        "snppurender.cpp",
        "snppurender8.cpp",
        "snrom.cpp",
        "snspc.c",
        "snspc_c.c",
        "snspcbrr.c",
        "snspcdisasm.c",
        "snspcdsp.cpp",
        "snspcio.cpp",
        "snspcmix.cpp",
        "snspcrom.c",
        "snspctimer.cpp",
        "snstate.cpp"
    ]
    
    static let libgep: [String] = [
        "bmpfile.cpp",
        "dataio.cpp",
        "emumovie.cpp",
        "emurom.cpp",
        "emushell.cpp",
        "emusys.cpp",
        "gzfileio.cpp",
        "inputdevice.cpp",
        "memspace.cpp",
        "memsurface.cpp",
        "mixbuffer.cpp",
        "mixconvert.cpp",
        "path.cpp",
        "pathext.cpp",
        "pixelformat.cpp",
        "surface.cpp",
        "wavfile.cpp"
    ]
    
    static let zlib: [String] = [
        "adler32.c",
        "compress.c",
        "crc32.c",
        "deflate.c",
        "gzio.c",
        "infblock.c",
        "infcodes.c",
        "inffast.c",
        "inflate.c",
        "inftrees.c",
        "infutil.c",
        "kos_zlib.c",
        "maketree.c",
        "trees.c",
        "uncompr.c",
        "zutil.c"
    ]

    static let unzip: [String] = [
        "explode.c",
        "unreduce.c",
        "unshrink.c",
        "unzip.c"
    ]
}

let package = Package(
    name: "PVSNESticle",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVSNESticle",
            targets: ["PVSNESticle", "PVSNESticleSwift", "libSNESticle"]),
        .library(
            name: "PVSNESticle-Dynamic",
            type: .dynamic,
            targets: ["PVSNESticle", "PVSNESticleSwift", "libSNESticle"]),
        .library(
            name: "PVSNESticle-Static",
            type: .static,
            targets: ["PVSNESticle", "PVSNESticleSwift", "libSNESticle"]),

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

        // MARK: --------- PVSNESticle ---------- //

        .target(
            name: "PVSNESticle",
            dependencies: [
                "libSNESticle",
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVPlists",
                "PVObjCUtils",
                "PVSNESticleSwift"
            ],
            cSettings: [
                .unsafeFlags(["-fmodules", "-fcxx-modules"]),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
            ]
        ),

        // MARK: --------- PVSNESticleSwift ---------- //

        .target(
            name: "PVSNESticleSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libSNESticle",
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .unsafeFlags(["-fmodules", "-fcxx-modules"]),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../virtualjaguar-libretro/src"),
                .headerSearchPath("../virtualjaguar-libretro/src/m68000"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common"),
                .headerSearchPath("../virtualjaguar-libretro/libretro-common/include"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),

        // MARK: --------- libSNESticle ---------- //

        .target(
            name: "libSNESticle",
            dependencies: ["libgep"],
            sources: Sources.libSNESticle.map { "SNESticle/SNESticle/Source/common/\($0)" },
            packageAccess: true,
            cSettings: [
//                .unsafeFlags(["-fmodules", "-fcxx-modules"]),
                .headerSearchPath("SNESticle/Gep/Include/common"),
                .headerSearchPath("SNESticle/Gep/Include/con32"),
                .headerSearchPath("SNESticle/Gep/Include/win32"),
            ]
        ),
        
        // MARK: --------- libSNESticle > libgep ---------- //

        .target(
            name: "libgep",
            path: "Sources/libSNESticle/SNESticle/Gep/",
            sources: Sources.libgep.map { "Source/common/\($0)" },
            packageAccess: true,
            cSettings: [
//                .unsafeFlags(["-fmodules", "-fcxx-modules"]),
                .headerSearchPath("Include/common"),
                .headerSearchPath("Include/con32"),
                .headerSearchPath("Include/win32"),
            ]
        ),


        // MARK: Tests
        .testTarget(
            name: "PVSNESticleTests",
            dependencies: [
                "PVSNESticle",
                "PVSNESticleSwift",
                "libSNESticle",
                "PVCoreBridge",
                "PVEmulatorCore"
            ],
            resources: [
                .copy("Resources/")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx20
)
