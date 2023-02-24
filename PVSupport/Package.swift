// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSupport",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVSupport",
            targets: ["PVSupport"]),
        .library(
            name: "PVSupport-Dynamic",
            type: .dynamic,
            targets: ["PVSupport"]),
        .library(
            name: "PVSupport-Static",
            type: .static,
            targets: ["PVSupport"])
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVLogging", path: "../PVLogging/"),
		.package(
			url: "https://github.com/SwiftGen/SwiftGenPlugin",
			from: "6.6.0"
		),
//        .package(
//			url: "https://github.com/JoeMatt/ZamzamKit.git",
//			revision: "dbbf712"
//        )
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVSupport
        .target(
            name: "PVSupport",
            dependencies: [
                "PVLogging",
//                .product(name: "ZamzamCore", package: "ZamzamKit"),
//                .product(name: "ZamzamLocation", package: "ZamzamKit"),
//                .product(name: "ZamzamNotification", package: "ZamzamKit"),
            ],
            resources: [
                .process("Resources/AHAP/")
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ],
			plugins: [
				.plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
			]
		)
    ]
)
