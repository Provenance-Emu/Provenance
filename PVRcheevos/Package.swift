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
//   CRcheevos   — C target; compiles all rcheevos .c sources; exposes rc_client.h etc.
//   PVRcheevos  — Swift target; re-exports CRcheevos and documents the integration.
//

import PackageDescription

// rcheevos C source files (relative to the rcheevos/ submodule root)
let rcheevosSources: [String] = [
    "src/rc_client.c",
    "src/rc_client_external.c",
    "src/rc_api_common.c",
    "src/rc_api_runtime.c",
    "src/rc_api_user.c",
    "src/rc_url.c",
    "src/rc_util.c",
    "src/rcheevos/alloc.c",
    "src/rcheevos/format.c",
    "src/rcheevos/lboard.c",
    "src/rcheevos/operand.c",
    "src/rcheevos/rc_validate.c",
    "src/rcheevos/richpresence.c",
    "src/rcheevos/runtime.c",
    "src/rcheevos/runtime_progress.c",
    "src/rcheevos/trigger.c",
    "src/rcheevos/value.c",
]

let package = Package(
    name: "PVRcheevos",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v13),
        .macCatalyst(.v17),
        .visionOS(.v1),
    ],
    products: [
        // PVRcheevos re-exports CRcheevos for Swift consumers.
        .library(name: "PVRcheevos",  targets: ["PVRcheevos"]),
        // CRcheevos is exposed separately so ObjC/C++ targets can depend on it directly.
        .library(name: "CRcheevos",   targets: ["CRcheevos"]),
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
                // Disable rcheevos's internal threading; Mednafen and most native cores
                // are single-threaded.  The server-call callback is the only async path.
                .define("RC_NO_THREADS", to: "1"),
            ]
        ),
        // MARK: - PVRcheevos (Swift entry point)
        .target(
            name: "PVRcheevos",
            dependencies: ["CRcheevos"],
            path: "Sources/PVRcheevos"
        ),
    ],
    cLanguageStandard: .c99
)
