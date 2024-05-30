// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVJIT",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
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
            name: "PVJITObjC",
            targets: ["PVJITObjC"]
        ),
        .library(
            name: "PVJITObjC-Dynamic",
            type: .dynamic,
            targets: ["PVJITObjC"]
        ),
        .library(
            name: "PVJITObjC-Static",
            type: .static,
            targets: ["PVJITObjC"]
        )
    ],

    dependencies: [
        .package(url: "https://github.com/SideStore/SideKit.git", branch: "main"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVJIT",
            dependencies: [
                "PVJITObjC",
                "PVSupport",
                "PVLogging",
			],
            linkerSettings: [
				.linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]),
        .target(
            name: "PVJITObjC",
            dependencies: [
                .productItem(name: "AltKit", package: "AltKit", moduleAliases: ["SideKit" : "AltKit"], condition: .when(platforms: [.iOS])),
                "AltKit",
                "PVSupport",
                "PVLogging",
            ],
            resources: [
                .process("Resources/")
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]),
        // MARK: SwiftPM tests
        .testTarget(
            name: "PVJITTests",
            dependencies: ["PVJIT"])
    ],
    swiftLanguageVersions: [.v5]
)
