// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVJIT",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PVJIT",
            targets: ["PVJIT"]
        ),
        .library(
            name: "PVJIT-Dynamic",
            type: .dynamic,
            targets: ["PVJIT"]
        ),
        .library(
            name: "PVJIT-Static",
            type: .static,
            targets: ["PVJIT"]
        ),
        .library(
            name: "JITManager",
            targets: ["JITManager"]
        ),

//        .library(
//            name: "FastmemUtil",
//            targets: ["FastmemUtil"]
//        ),
    ],

    dependencies: [
        .package(url: "https://github.com/SideStore/SideKit.git", revision: "ab959a54fc2217464ffabd09322ec3351e3ca456"),
//        .package(url: "https://github.com/SideStore/SideKit.git", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVJIT",
            dependencies: [
                "PVSupport",
                .product(name: "PVLogging", package: "pvlogging"),
                /// SideKit supports tvOS; unconditional dep satisfies Swift 6 dependency scan for `#if _USE_ALTKIT` + `import SideKit` in JITManager sources.
                .product(name: "SideKit", package: "sidekit"),
                "JITManager",
                "FastmemUtil"
            ],
            // TODO: These define's are really left over from objective-c using xcode xccnfig schemes
            // this needs to be worked into CI or replaced with all runtime checks
            swiftSettings: [
                .define("_USE_ALTKIT", .when(platforms: [.iOS])),
                .define("APP_STORE"),
                .define("NONJAILBROKEN"),
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
            ]),

//        .target(
//            name: "PVJITObjC",
//            dependencies: [
//                "SideKit",
//                "PVSupport",
//                "PVLogging",
//            ],
//            linkerSettings: [
//                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
//                .linkedFramework("AppKit", .when(platforms: [.macOS])),
//        ]),

        .target(
            name: "FastmemUtil"
        ),

        .target(
            name: "JITManager",
            dependencies: [
                .product(name: "PVLogging", package: "pvlogging"),
                "DebuggerUtils",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SideKit", package: "sidekit"),
            ],
            swiftSettings: [
                .define("_USE_ALTKIT", .when(platforms: [.iOS])),
                .define("APP_STORE"),
            ],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),

        .target(
            name: "DebuggerUtils",
            publicHeadersPath: "./"
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVJITTests",
            dependencies: ["PVJIT", "JITManager"])
    ],
    swiftLanguageModes: [.v5]
)
