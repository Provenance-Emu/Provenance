// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PVPatchEngine",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PVPatchEngine", targets: ["PVPatchEngine"])
    ],
    targets: [
        // Vendored xdelta3 (Apache-2.0 branch release3_1_apl, reports 3.1.1) plus a small pv_ shim
        // that hides the xd3 types from Swift. Only the decoder is used; the encoder stays compiled
        // because xdelta3-fgk.h references encoder symbols and does not build with XD3_ENCODER=0.
        .target(
            name: "CXdelta3",
            exclude: ["LICENSE", "xdelta3-lzma.h"],
            cSettings: [
                .define("static_assert", to: "_Static_assert"),
                .define("XD3_USE_LARGEFILE64", to: "1"),
                .define("XD3_ENCODER", to: "1"),
                .define("XD3_DEBUG", to: "0"),
                .define("SECONDARY_DJW", to: "1"),
                .define("SECONDARY_FGK", to: "1"),
                .define("SECONDARY_LZMA", to: "0"),
                .define("SIZEOF_SIZE_T", to: "__SIZEOF_SIZE_T__"),
                .define("SIZEOF_UNSIGNED_INT", to: "__SIZEOF_INT__"),
                .define("SIZEOF_UNSIGNED_LONG", to: "__SIZEOF_LONG__"),
                .define("SIZEOF_UNSIGNED_LONG_LONG", to: "__SIZEOF_LONG_LONG__")
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "PVPatchEngine",
            dependencies: ["CXdelta3"]
        ),
        .testTarget(
            name: "PVPatchEngineTests",
            dependencies: ["PVPatchEngine"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
