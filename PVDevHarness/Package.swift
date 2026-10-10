// swift-tools-version:6.0
import PackageDescription

// Dev-only launch-argument harness, compiled into Tuist focused apps under PV_DEV_HARNESS.
// PVDevHarnessKit is platform-neutral (arguments, report, output files) and unit-tested with
// `swift test` on macOS; PVDevHarness drives the app and only builds for iOS/tvOS.
let appPlatforms: [Platform] = [.iOS, .tvOS]

let package = Package(
    name: "PVDevHarness",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "PVDevHarness", targets: ["PVDevHarness"]),
    ],
    dependencies: [
        .package(path: "../PVUI"),
        .package(path: "../PVLibrary"),
        .package(path: "../PVLogging"),
    ],
    targets: [
        .target(name: "PVDevHarnessKit"),
        .target(
            name: "PVDevHarness",
            dependencies: [
                "PVDevHarnessKit",
                .product(name: "PVUI", package: "PVUI", condition: .when(platforms: appPlatforms)),
                .product(name: "PVLibrary", package: "PVLibrary", condition: .when(platforms: appPlatforms)),
                .product(name: "PVLogging", package: "PVLogging", condition: .when(platforms: appPlatforms)),
            ]
        ),
        .testTarget(name: "PVDevHarnessKitTests", dependencies: ["PVDevHarnessKit"]),
    ],
    swiftLanguageModes: [.v5]
)
