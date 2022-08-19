// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLibrary",
    platforms: [
		.iOS(.v13),
		.tvOS(.v13),
		.macCatalyst(.v14),
		.macOS(.v11)
    ],
    products: [
        .library(
            name: "PVLibrary",
            targets: ["PVLibrary"])
    ],
    dependencies: [
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
            url: "https://github.com/stephencelis/SQLite.swift",
            .upToNextMajor(from: "0.13.3")),
        .package(
            url: "https://github.com/ZipArchive/ZipArchive",
            .upToNextMajor(from: "2.5.2")),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxReachability",
            .upToNextMajor(from: "1.2.1")),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxDataSources",
            .upToNextMajor(from: "5.0.0")),
        .package(
            url: "https://github.com/tsolomko/SWCompression",
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
                "RxDataSources",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "PVLibrary",
            exclude: [
                "PVLibrary-iOS-Info.plist",
                "PVLibrary-tvOS-Info.plist",
                "PVLibrary-watchOS-Info.plist",
                "SQLitePlatform",
                "Syncing"
            ],
            resources: [
                .process("Resources/"),
            ]),
        // // MARK: SwiftPM tests
        // .testTarget(
        //     name: "PVLibraryTests",
        //     dependencies: ["PVLibrary"],
        //     path: "Tests")
    ]
)
