// swift-tools-version: 6.0
// PVRcheevos — Shared SPM wrapper around the rcheevos C library.
//
// ## Setup
//
//   git submodule update --init PVRcheevos/rcheevos
//
// The rcheevos submodule lives at PVRcheevos/rcheevos/ (github.com/RetroAchievements/rcheevos).
// All emulator cores that need rc_client-based achievements should depend on this package
// rather than bundling their own copy.
//
// ## Targets
//
//   CRcheevos       — C target; compiles all rcheevos .c sources; exposes rc_client.h etc.
//                     Requires the rcheevos git submodule (see Setup above).
//   PVRcheevosCore  — Pure-Swift utilities (byte-swap, address constants, region descriptors).
//                     No C dependency — safe on all platforms including Linux.
//                     Lives in the sibling PVRcheevosCore/ package and is re-exported here.
//   PVRcheevos      — Swift entry point; re-exports both CRcheevos and PVRcheevosCore.
//
// ## Testing
//
//   Tests live in PVRcheevosCore/ (no submodule needed):
//     cd PVRcheevosCore && swift test
//

import PackageDescription

// rcheevos C source files (relative to the rcheevos/ submodule root)
let rcheevosSources: [String] = [
    // Top-level client
    "src/rc_client.c",
    "src/rc_client_external.c",
    // Utilities
    "src/rc_compat.c",
    "src/rc_util.c",
    "src/rc_version.c",
    // libretro memory-map helper (flat<->bus address translation for thin wrapper)
    "src/rc_libretro.c",
    // REST API helpers (in rapi/ subdirectory)
    "src/rapi/rc_api_common.c",
    "src/rapi/rc_api_editor.c",
    "src/rapi/rc_api_info.c",
    "src/rapi/rc_api_runtime.c",
    "src/rapi/rc_api_user.c",
    // Core evaluation engine
    "src/rcheevos/alloc.c",
    "src/rcheevos/condition.c",
    "src/rcheevos/condset.c",
    "src/rcheevos/consoleinfo.c",
    "src/rcheevos/format.c",
    "src/rcheevos/lboard.c",
    "src/rcheevos/memref.c",
    "src/rcheevos/operand.c",
    "src/rcheevos/rc_validate.c",
    "src/rcheevos/richpresence.c",
    "src/rcheevos/runtime.c",
    "src/rcheevos/runtime_progress.c",
    "src/rcheevos/trigger.c",
    "src/rcheevos/value.c",
    // ROM hashing
    "src/rhash/aes.c",
    "src/rhash/cdreader.c",
    "src/rhash/hash.c",
    "src/rhash/hash_disc.c",
    "src/rhash/hash_encrypted.c",
    "src/rhash/hash_rom.c",
    "src/rhash/hash_zip.c",
    "src/rhash/md5.c",
]

let package = Package(
    name: "PVRcheevos",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1),
    ],
    products: [
        // PVRcheevos re-exports CRcheevos and PVRcheevosCore for Swift consumers.
        .library(name: "PVRcheevos",  targets: ["PVRcheevos"]),
        // CRcheevos is exposed separately so ObjC/C++ targets can depend on it directly.
        .library(name: "CRcheevos",   targets: ["CRcheevos"]),
    ],
    dependencies: [
        // Pure-Swift utilities with no C dependency.
        // Tests live here so they can run without the rcheevos submodule.
        .package(path: "../PVRcheevosCore"),
    ],
    targets: [
        // MARK: - CRcheevos (C library)
        .target(
            name: "CRcheevos",
            // NOTE: `path` points to the git submodule directory.
            // Run `git submodule update --init PVRcheevos/rcheevos` before building.
            path: "rcheevos",
            sources: rcheevosSources,
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                // rc_libretro.c includes "libretro.h", which rcheevos vendors under test/.
                .headerSearchPath("test"),
                // RC_NO_THREADS removes rcheevos's internal mutex entirely.
                // This is safe for Mednafen (single emulator thread) but means any
                // core that calls doFrame from a different thread than loginAndLoadGame
                // must provide its own synchronisation.  Do NOT set this flag in cores
                // that drive rc_client from multiple threads.
                .define("RC_NO_THREADS", to: "1"),
                // RC_CLIENT_SUPPORTS_HASH compiles in `rc_client_begin_identify_and_load_game`
                // (and the iterator-driven hashing glue it uses). RetroArch's full cheevos.c
                // calls this entry point with `RC_CONSOLE_UNKNOWN` and lets rcheevos pick the
                // matching console + hash from the file path/contents — we want the same
                // capability available to Provenance frontends.
                .define("RC_CLIENT_SUPPORTS_HASH", to: "1"),
            ]
        ),
        // MARK: - PVRcheevos (Swift entry point, re-exports both)
        .target(
            name: "PVRcheevos",
            dependencies: [
                "CRcheevos",
                .product(name: "PVRcheevosCore", package: "PVRcheevosCore"),
            ],
            path: "Sources/PVRcheevos"
        ),
    ],
    cLanguageStandard: .c99
)
