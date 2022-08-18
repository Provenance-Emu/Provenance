// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let loggingPlatforms: [Platform] = [.tvOS, .iOS, .macOS, .macCatalyst]
let package = Package(
	name: "PVSupport",
	platforms: [
		.iOS(.v13),
		.tvOS(.v13),
		.macCatalyst(.v14),
		.macOS(.v11),
//		.watchOS(.v8),
		//		.custom("Linux", versionString: "1.0")
		//		.driverKit(.v21)
	],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "PVSupport",
			targets: ["PVSupport"]),
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		.package(
			url: "https://github.com/CocoaLumberjack/CocoaLumberjack",
			.upToNextMajor(from: "3.7.2")),
		.package(
			name: "Reachability",
			url: "https://github.com/ashleymills/Reachability.swift",
			.upToNextMajor(from: "5.1.0")),
		.package(
			url: "https://github.com/fpillet/NSLogger",
			.branch("master"))
	],
	targets: [
		.target(
			name: "PVSupport",
			dependencies: [
				.product(name: "CocoaLumberjack", package: "CocoaLumberjack", condition: .when(platforms: loggingPlatforms)),
				.product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack", condition: .when(platforms: loggingPlatforms)),
				.product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack", condition: .when(platforms: loggingPlatforms)),
				.byName(name: "NSLogger", condition: .when(platforms: loggingPlatforms)),
				.byName(name: "Reachability", condition: .when(platforms: loggingPlatforms))],
			path: "Sources/PVSupport",
			exclude: [
				"Performance/PerformanceView.swift",
				"Performance/Performance.swift"],
			resources: [
				.process("Controller/AHAP/")
			],
			publicHeadersPath: "Public Headers",
			swiftSettings: [.define("GLES_SILENCE_DEPRECATION")],
			linkerSettings: [
				.linkedLibrary("openssl", .when(platforms: [.linux])),
			]
		),
		// MARK: SwiftPM tests
			.testTarget(
				name: "PVSupportTests",
				dependencies: ["PVSupport"])
	]
)
