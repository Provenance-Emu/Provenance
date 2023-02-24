// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLogging",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLogging",
            targets: ["PVLogging"]),
        .library(
            name: "PVLogging-Dynamic",
            type: .dynamic,
            targets: ["PVLogging"]),
        .library(
            name: "PVLogging-Static",
            type: .static,
            targets: ["PVLogging"])
    ],
    dependencies: [
        .package(
			url: "https://github.com/fpillet/NSLogger",
				 revision: "e8c453142da7051462cca189d3fcee74de0500ea"
		),
		.package(
			url: "https://github.com/apple/swift-log.git",
			from: "1.5.2"
		),
        // Dependencies declare other packages that this package depends on.
        // .package(
        //     url: "https://github.com/immobiliare/Glider.git",
        //     .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(
            name: "PVLoggingObjC",
            dependencies: [
                "NSLogger",
				.product(name: "Logging", package: "swift-log")
            ],
            publicHeadersPath: "include/"
        ),
        .target(
            name: "PVLogging",
            dependencies: [
                "NSLogger",
                "PVLoggingObjC"
            ],
            publicHeadersPath: "include/"
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLoggingTests",
            dependencies: ["PVLogging"],
            path: "Tests")
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx17
)
