// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let cxxSettings: [CXXSetting] = [
	// .define("STEAMCONTROLLER_NO_PRIVATE_API", .when(platforms: [.macOS])),
]

let cSettings: [CSetting] = [
	// .define("STEAMCONTROLLER_NO_PRIVATE_API", .when(platforms: [.macOS])),
	// .define("STEAMCONTROLLER_NO_SWIZZLING")
]

let package = Package(
	name: "Provenance",
	platforms: [
		.iOS(.v11),
		.tvOS(.v11),
        // .watchOS(.v7),
		// .macOS(.v10_13)
	],
	products: [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "PVApp",
			targets: ["PVApp"]),
		.executable(
			name: "Provenance",
			targets: ["Provenance"]),
	],
	dependencies: [
    //     .package(
	// 		name: "RxSwift",
	// 		url: "https://github.com/ReactiveX/RxSwift.git")
    ],
	targets: [
		.target(
			name: "PVApp",
			dependencies: [
				"PVSupport", "PVLibrary"
			],
			path: "PVApp")
		.target(
			name: "Provenance",
			dependencies: [
				"PVApp", "PVSupport", "PVLibrary"
			],
			path: "Provenance")
	]
)
