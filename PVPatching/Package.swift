// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVPatching",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVPatching",
            targets: ["PVPatching"]
        )
    ],
    dependencies: [
        .package(path: "../PVLogging"),
        // Streaming IPS/BPS/UPS/PPF/xdelta3 engine shared with iCube and iFly. Change it in that
        // repo, tag a release, then bump the version here; there is no local copy to edit.
        .package(url: "https://github.com/Provenance-Emu/PVPatchEngine.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "PVPatching",
            dependencies: [
                "PVLogging",
                .product(name: "PVPatchEngine", package: "PVPatchEngine")
            ],
            path: "Sources/PVPatching"
        ),
        .testTarget(
            name: "PVPatchingTests",
            dependencies: ["PVPatching"],
            path: "Tests/PVPatchingTests",
            resources: [
                .copy("Resources")
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
