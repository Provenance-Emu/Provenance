// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVApp",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVApp",
            targets: ["PVApp"]
        ),
        .library(
            name: "PVApp-Dynamic",
            type: .dynamic,
            targets: ["PVApp"]
        ),
        .library(
            name: "PVApp-Static",
            type: .static,
            targets: ["PVApp"]
        )
    ],

    dependencies: [
        .package(name: "PVLibrary", path: "../PVLibrary/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVLogging", path: "../PVLogging/"),
		.package(name: "PVEmulatorCore", path: "../PVEmulatorCore/"),
		.package(
			url: "https://github.com/ReactiveX/RxSwift",
			.upToNextMajor(from: "6.5.0")
		),
		.package(
			url: "https://github.com/RxSwiftCommunity/RxDataSources.git",
			.upToNextMajor(from: "5.0.0")
		),
    ],

    // MARK: - Targets
    targets: [
        .target(
            name: "PVApp",
            dependencies: [
				.product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                "PVSupport",
                "RxDataSources",
                "PVLibrary",
                "PVLogging",
				.product(name: "RxCocoa", package: "RxSwift")
			],
            linkerSettings: [
				.linkedFramework("MetalKit"),
				.linkedFramework("Metal"),
				.linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
				.linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
				.linkedFramework("OpenGL", .when(platforms: [.macOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ]),
        // MARK: SwiftPM tests
        .testTarget(
            name: "PVAppTests",
            dependencies: ["PVApp"])
    ]
//    cLanguageStandard: .c17,
//    cxxLanguageStandard: .cxx17
)
