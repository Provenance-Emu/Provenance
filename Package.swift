// swift-tools-version:5.9
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
		.iOS(.v17),
		.tvOS(.v17),
        .watchOS(.v9),
		.macOS(.v14)
	],
	products: [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "PVLibrary",
			targets: ["PVLibrary"]),
		.library(
			name: "PVLibrary-ObjC",
			targets: ["PVLibrary-ObjC"])
		// .library(
		// 	name: "PVSupport",
		// 	targets: ["PVSupport"]),
		// .library(
		// 	name: "PVSupport-ObjC",
		// 	targets: ["PVSupport-ObjC"])
	],
	dependencies: [
    //     .package(
	// 		name: "RxSwift",
	// 		url: "https://github.com/ReactiveX/RxSwift.git")
    ],
	targets: [
		.target(
			name: "PVLibrary",
			// dependencies: [
			// 	.product(name: "RxSwift", package: "RxSwift")
			// ],
			path: "PVLibrary",
			exclude: ["Info.plist", "*.m"],
			cSettings: cSettings,
			cxxSettings: cxxSettings),

		.target(
			name: "PVLibrary-ObjC",
			// dependencies: [
			// 	.product(name: "RxSwift", package: "RxSwift")
			// ],
			path: "PVLibrary",
			exclude: ["Info.plist", "*.swift"],
			cSettings: cSettings,
			cxxSettings: cxxSettings)
	]
)
