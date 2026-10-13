// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVShaders",
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
            name: "PVShaders",
            targets: ["PVShaders"]
        ),
        .library(
            name: "PVSlangRuntime",
            targets: ["PVSlangRuntime"]
        )
    ],
    dependencies: [
        .package(path: "../PVPrimitives"),
        .package(path: "../PVLogging"),
        .package(path: "../PVSettings"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2")
    ],
    targets: [
        // OpenEmu-Shaders runtime (BSD-3, see file headers): runs libretro slang
        // presets compiled to MSL by the oeshaders tool.
        .target(
            name: "PVSlangRuntime",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "PVShaders",
            dependencies: [
                "PVSlangRuntime",
                "PVPrimitives",
                "PVLogging",
                "PVSettings",
                "Defaults"
            ],
            resources: [
                .process("Resources/Metal")
            ]
        ),
        .testTarget(
            name: "PVShadersTests",
            dependencies: ["PVShaders", "PVSlangRuntime"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
