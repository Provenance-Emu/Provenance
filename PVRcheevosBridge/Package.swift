// swift-tools-version: 6.0
// PVRcheevosBridge — Glues PVRcheevos (rc_client wrapper) onto PVCoreBridge's
// `CoreRetroAchievements` protocol so emulator cores can opt into the shared
// rc_client integration with a single method.
//
// ## Why a separate module?
//
// `PVRcheevos` is intentionally kept free of `PVCoreBridge` (and therefore
// of PVAudio/PVPrimitives etc.) so it can be consumed by lighter contexts —
// e.g. the import pipeline and the emulator-VC fallback hash path. Anything
// that adapts the closure-based `RcheevosSession` to the bridge's delegate
// protocol must depend on both, so it lives here.
//
// ## How cores opt in
//
//   class MyCoreBridge: PVEmulatorCore, CoreRetroAchievements {
//       func rcheevosRegions() -> [RcheevosRegion] {
//           // describe the system's RAM map
//       }
//   }
//
// Default implementations of every other `CoreRetroAchievements` requirement
// (lifecycle, delegate, tick, hardcore flag) are supplied by this module and
// share a single `RcheevosSession` per core instance. State is held in an
// associated object so no stored properties need to be added on the core side.
//

import PackageDescription

let package = Package(
    name: "PVRcheevosBridge",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "PVRcheevosBridge", targets: ["PVRcheevosBridge"]),
    ],
    dependencies: [
        .package(name: "PVRcheevos", path: "../PVRcheevos/"),
        .package(name: "PVCoreBridge", path: "../PVCoreBridge/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
    ],
    targets: [
        .target(
            name: "PVRcheevosBridge",
            dependencies: [
                .product(name: "PVRcheevos", package: "PVRcheevos"),
                .product(name: "PVCoreBridge", package: "PVCoreBridge"),
                .product(name: "PVLogging", package: "PVLogging"),
            ],
            path: "Sources/PVRcheevosBridge"
        ),
    ],
    swiftLanguageModes: [.v5, .v6]
)
