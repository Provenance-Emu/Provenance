// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/* NOTE: this package does not build yet.
 *
 * This manifest was a verbatim copy of Cores/Stella/Package.swift -- package
 * "PVStella" with targets "PVStella", "PVStellaSwift", "PVStellaCPP" and
 * "libstella", and a body full of Stella-specific excludes, defines and
 * `stella/src/...` header paths. Those names belong to Cores/Stella, which IS
 * registered as an XCLocalSwiftPackageReference in Provenance.xcodeproj, and
 * SPM requires target and product names to be unique across the whole package
 * graph -- so the copy was a latent collision.
 *
 * The names below are PVFCEU's own and the Stella-specific settings are gone,
 * which removes the collision. The targets still have no sources: PVFCEU has
 * never been migrated to SPM and has no Sources/ layout, so `swift build`
 * fails with "Source files for target ... should be located under". Wiring
 * that up means splitting the mixed ObjC++/Swift core at the repo root and enumerating fceux/, which is a source
 * migration, not a manifest change. PVFCEU.xcodeproj remains the build path.
 */
let package = Package(
    name: "PVCoreFCEU",
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
            name: "PVFCEU",
            targets: ["PVFCEU", "PVFCEUSwift"]),
        .library(
            name: "PVFCEU-Dynamic",
            type: .dynamic,
            targets: ["PVFCEU", "PVFCEUSwift"]),
        .library(
            name: "PVFCEU-Static",
            type: .static,
            targets: ["PVFCEU", "PVFCEUSwift"]),
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
        .target(
            name: "PVFCEU",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVFCEUSwift",
                "PVFCEUCPP",
                "libfceu",
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            publicHeadersPath: "include",
            cSettings: CommonSettings.c,
            cxxSettings: CommonSettings.cxx,
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "PVFCEUSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libfceu",
                "PVFCEUCPP"
            ],
            cSettings: CommonSettings.c,
            cxxSettings: CommonSettings.cxx,
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "PVFCEUCPP",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libfceu",
            ],
            publicHeadersPath: "./",
            cSettings: CommonSettings.c,
            cxxSettings: CommonSettings.cxx
        ),

        .target(
            name: "libfceu",
            packageAccess: true,
            cSettings: CommonSettings.c,
            cxxSettings: CommonSettings.cxx
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)

enum CommonSettings {
    static let c: [CSetting] = [
        .define("INLINE", to: "inline"),
        .define("USE_STRUCTS", to: "1"),
        .define("__LIBRETRO__", to: "1"),
        .define("HAVE_COCOATOJUCH", to: "1"),
        .define("__GCCUNIX__", to: "1"),
    ]

    static let cxx: [CXXSetting] = [
        .define("INLINE", to: "inline"),
        .define("USE_STRUCTS", to: "1"),
        .define("__LIBRETRO__", to: "1"),
        .define("HAVE_COCOATOJUCH", to: "1"),
        .define("__GCCUNIX__", to: "1"),
    ]
}
