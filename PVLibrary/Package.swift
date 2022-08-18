// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLibrary",
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
            name: "PVLibrary",
            targets: ["PVLibrary"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            name: "PVSupport",
            path: "../PVSupport"),
        .package(
            url: "https://github.com/ReactiveX/RxSwift",
            .upToNextMajor(from: "6.5.0")),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxRealm",
            .upToNextMajor(from: "5.0.5")),
        .package(
            name: "SQLite.swift",
            url: "https://github.com/stephencelis/SQLite.swift",
            .upToNextMajor(from: "0.13.3")),
        .package(
            name: "ZipArchive",
            url: "https://github.com/ZipArchive/ZipArchive",
            .upToNextMajor(from: "2.5.2")),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxReachability",
            .upToNextMajor(from: "1.2.1")),
        .package(
            url: "https://github.com/groue/GRDB.swift.git",
            .upToNextMajor(from: "5.26.0")),
        // .package(
        //     name: "Reachability",
        //     url: "https://github.com/realm/realm-cocoa",
        //     .upToNextMajor(from: "10.20.2")),
        .package(
            name: "SWCompression",
            url: "https://github.com/tsolomko/SWCompression.git",
            .upToNextMajor(from: "4.8.1"))
    ],
    targets: [
        .target(
            name: "PVLibrary",
            dependencies: [
                "PVSupport",
                "SWCompression",
                "ZipArchive",
                "RxReachability",
                "GRDB",
                // "Realm",
                // "RealmSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "PVLibrary",
            // exclude: [
            //     "Info.plist"
            // ],
            resources: [
                .process("Resources/")
            ]),
        // // MARK: SwiftPM tests
        // .testTarget(
        //     name: "PVLibraryTests",
        //     dependencies: ["PVLibrary"],
        //     path: "Tests")
    ]
)
