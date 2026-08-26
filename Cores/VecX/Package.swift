// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/* This manifest used to be a verbatim copy of Cores/Stella/Package.swift --
 * package "PVStella" with targets "PVStella", "PVStellaSwift", "PVStellaCPP"
 * and "libstella". Those names belong to Cores/Stella, which IS registered as
 * an XCLocalSwiftPackageReference in Provenance.xcodeproj, and SPM requires
 * target and product names to be unique across the whole package graph.
 *
 * The names below match the directories that already exist under Sources/,
 * which were laid out for this package but never wired up. `libvecx` and
 * `PVVecXC` build; the core bridge does not yet -- Sources/PVVecX is a mixed
 * ObjC++/Swift Xcode framework target (PVVecXCore.mm does
 * `#import <PVVecX/PVVecX-Swift.h>`), and SPM cannot express a single
 * mixed-language target. Splitting it is a source migration, not a manifest
 * change; PVVecX.xcodeproj remains the build path until then.
 */
let package = Package(
    name: "PVCoreVecX",
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
            name: "PVVecX",
            targets: ["PVVecX", "PVVecXBridge"]),
        .library(
            name: "PVVecX-Dynamic",
            type: .dynamic,
            targets: ["PVVecX", "PVVecXBridge"]),
        .library(
            name: "PVVecX-Static",
            type: .static,
            targets: ["PVVecX", "PVVecXBridge"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils")
    ],
    targets: [

        // MARK: ------- Core (Swift) -------

        .target(
            name: "PVVecX",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVVecXBridge",
                "PVVecXC",
                "libvecx",
            ],
            path: "Sources/PVVecX",
            exclude: Sources.bridge + ["include", "Resources/Info.plist", "Resources/PVVecX.h"],
            sources: Sources.swift,
            resources: [
                .process("Resources/Core.plist")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        // MARK: ------- Core (ObjC++ bridge) -------

        .target(
            name: "PVVecXBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVObjCUtils",
                "PVVecXC",
                "libvecx",
            ],
            path: "Sources/PVVecX",
            exclude: Sources.swift + ["Resources"],
            sources: Sources.bridge,
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAS_GPU", to: "1"),
                .headerSearchPath("../libvecx/libretro-vecx/libretro-common/include"),
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ]),
                .define("INLINE", to: "inline"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAS_GPU", to: "1"),
                .headerSearchPath("../libvecx/libretro-vecx/libretro-common/include"),
            ]
        ),

        // MARK: ------- libretro shim -------

        .target(
            name: "PVVecXC",
            dependencies: [
                "libvecx",
            ],
            path: "Sources/PVVecXC",
            publicHeadersPath: "./",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("__LIBRETRO__", to: "1"),
                .headerSearchPath("../libvecx/libretro-vecx/libretro-common/include"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("__LIBRETRO__", to: "1"),
                .headerSearchPath("../libvecx/libretro-vecx/libretro-common/include"),
            ]
        ),

        // MARK: ------- Emulator core -------

        .target(
            name: "libvecx",
            path: "Sources/libvecx",
            sources: Sources.libvecx,
            publicHeadersPath: "libretro-vecx/libretro-common/include",
            packageAccess: true,
            cSettings: [
                .define("__LIBRETRO__", to: "1"),
                .define("STATIC_LINKING", to: "1"),
                .define("FRONTEND_SUPPORTS_RGB565", to: "1"),
                .define("HAVE_STRINGS", to: "1"),
                .define("HAVE_STDINT_H", to: "1"),
                .define("HAVE_INTTYPES_H", to: "1"),
                .define("INLINE", to: "inline"),
                /* Xcode sets these unconditionally via BuildFlags.xcconfig,
                 * which only ever builds this core for the iOS family. */
                .define("IOS", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("HAVE_OPENGLES", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("HAVE_OPENGLES2", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("HAS_GPU", to: "1", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .headerSearchPath("libretro-vecx"),
                .headerSearchPath("libretro-vecx/libretro-common/include"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)

enum Sources {
    /* Mirrors the `vecx-libretro` target in PVVecX.xcodeproj. */
    static let libvecx: [String] = [
        "libretro-vecx/e6809.c",
        "libretro-vecx/e8910.c",
        "libretro-vecx/vecx.c",
        "libretro-vecx/libretro.c",
        "libretro-vecx/libretro-common/glsm/glsm.c",
        "libretro-vecx/libretro-common/glsym/glsym_es2.c",
        "libretro-vecx/libretro-common/glsym/rglgen.c",
    ]

    /* Sources/PVVecX is a single mixed-language Xcode framework target; SPM
     * needs it split by language across two targets over the same path. */
    static let bridge: [String] = [
        "PVVecXCore.mm",
        "PVVecXCore+Audio.m",
        "PVVecXCore+Controls.mm",
        "PVVecXCore+Saves.m",
        "PVVecXCore+Video.m",
    ]

    static let swift: [String] = [
        "PVVecXCore.swift",
        "PVVecXCore+CompanionController.swift",
        "VecxOptions.swift",
        "CorePlist.swift",
        "CorePlist-Generated.swift",
    ]
}
