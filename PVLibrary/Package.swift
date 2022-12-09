// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLibrary",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v7),
        .macOS(.v11)
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
            .upToNextMajor(from: "6.2.0")),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxRealm",
            .upToNextMajor(from: "5.0.3")),
        .package(
            name: "SQLite.swift",
            url: "https://github.com/stephencelis/SQLite.swift",
            .upToNextMajor(from: "0.12.2")),
        .package(
            name: "ZipArchive",
            url: "https://github.com/ZipArchive/ZipArchive",
            .upToNextMajor(from: "2.3.0")),
        .package(
            name: "Reachability",
            url: "https://github.com/realm/realm-cocoa",
            .upToNextMajor(from: "10.20.2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "PVLibraryObjC",
            dependencies: [
                "PVSupport",
                // "Realm",
                // "RealmSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "ZipArchive", package: "ZipArchive")
            ],
            path: "PVLibrary",
            sources: [
                "Database/OESQLiteDatabase.m",
                "NSExtensions/NSFileManager+Hashing.m",
                "NSExtensions/UIImage+Scaling.m",
                "NSExtensions/NSString+Hashing.m",
                "NSExtensions/NSData+Hashing.m"
                // "LzmaSDKObjC/src/LzmaSDKObjC.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCBufferProcessor.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCCrc.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCError.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCExtern.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCExtractCallback.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCItem.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCMutableItem.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCReader.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCUpdateCallback.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCWriter.mm",
            ],
            publicHeadersPath: "Public Headers"),

        .target(
            name: "LzmaSDKObjC",
            path: "LzmaSDKObjC"
        ),

        .target(
            name: "PVLibrary",
            dependencies: [
                "PVSupport",
                "LzmaSDKObjC",
                "PVLibraryObjC",
                // "Realm",
                // "RealmSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "ZipArchive", package: "ZipArchive")
            ],
            path: "PVLibrary",
            exclude: [
                "Database/OESQLiteDatabase.m",
                "NSExtensions/NSFileManager+Hashing.m",
                "NSExtensions/UIImage+Scaling.m",
                "NSExtensions/NSString+Hashing.m",
                "NSExtensions/NSData+Hashing.m",
                "Info.plist"
                // "LzmaSDKObjC/src/LzmaSDKObjC.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCBufferProcessor.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCCrc.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCError.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCExtern.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCExtractCallback.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCItem.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCMutableItem.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCReader.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCUpdateCallback.mm",
                // "LzmaSDKObjC/src/LzmaSDKObjCWriter.mm",
            ],
            resources: [
                .process("Resources/")
            ]),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLibraryTests",
            dependencies: ["PVLibrary"],
            path: "Tests")
    ]
)
