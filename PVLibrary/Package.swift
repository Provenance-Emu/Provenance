// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

#if swift(>=5.9)
let swiftSettings: [SwiftSetting] = [
    //    .interoperabilityMode(.Cxx)
]
#else
let swiftSettings: [SwiftSetting] = [
]
#endif

let linkerSettings: [LinkerSetting] = [
    .linkedFramework("Foundation"),
    .linkedFramework("CoreGraphics"),
    .linkedFramework("CoreSpotlight"),
    .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
    .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .watchOS, .macCatalyst])),
    .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
]

let package = Package(
    name: "PVLibrary",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLibrary",
            targets: ["PVLibrary"]
        ),
        .library(
            name: "PVLibrary-Static",
            type: .static,
            targets: ["PVLibrary"]
        ),
        .library(
            name: "PVLibrary-Dynamic",
            type: .dynamic,
            targets: ["PVLibrary"]
        ),
    ],
    dependencies:
        ["Support", "Logging", "Hashing",
         "EmulatorCore", "CoreLoader", "Primitives",
         "Plists", "Lookup", "Settings", "FeatureFlags"]
        .map { .package(path: "../PV\($0)") }
        + [
        .package(url: "https://github.com/ReactiveX/RxSwift.git",
                 .upToNextMajor(from: "6.7.1")),
        .package(url: "https://github.com/RxSwiftCommunity/RxRealm.git",
                 branch: "main"),
        .package(url: "https://github.com/ZipArchive/ZipArchive.git",
                 exact: "2.4.3"),
        .package(url: "https://github.com/OlehKulykov/PLzmaSDK.git",
                 revision: "1.2.5"),
//        .package(url: "https://github.com/tsolomko/SWCompression.git",
//                 .upToNextMinor(from: "4.8.6")),
        .package(url: "https://github.com/JoeMatt/SWCompression.git",
                 branch: "develop"),
        .package(url: "https://github.com/apple/swift-async-algorithms",
                 from: "1.0.0"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git",
                 branch: "develop"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git",
                 .upToNextMajor(from: "0.15.3")),
        .package(url: "https://github.com/pointfreeco/swift-perception.git",
                 branch:("main")),
        /// https://github.com/mtgto/Unrar.swift
        .package(url: "https://github.com/mtgto/Unrar.swift.git",
                    .upToNextMajor(from: "0.3.16")),
    ],

    targets: [
        // MARK: ------------ SwiftCloudDrive ------------
        .target(
            name: "SwiftCloudDrive",
            dependencies: [
                "PVLogging"
            ]
        ),
        // MARK: ------------ PVLibrary ------------
        .target(
            name: "PVLibrary",
            dependencies: [
                "PVSupport",
                "PLzmaSDK",
                "SWCompression",
                "PVLogging",
                "PVHashing",
                "PVPlists",
                "PVLookup",
                "PVPrimitives",
                "PVRealm",
                "PVFeatureFlags",
                "Extractor",
                "PVFileSystem",
                "PVMediaCache",
                "PVSettings",
                "PVEmulatorCore",
                "PVCoreLoader",
//                "Unrar",
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Perception", package: "swift-perception"),
            ],
            resources: [
                // TODO: Move Cheats to PVLookup
                .process("Resources/cheatbase.sqlite"),
                .process("Resources/systems.plist")
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]),
        // MARK: ------------ PVRealm ------------
        .target(
            name: "PVRealm",
            dependencies: [
                "PVSupport",
                "PLzmaSDK",
                "SWCompression",
                "PVLogging",
                "PVHashing",
                "PVPlists",
                "PVLookup",
                "PVPrimitives",
                "PVMediaCache",
                .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                .product(name: "PVCoreLoader", package: "PVCoreLoader"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "ZipArchive", package: "ZipArchive"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]),
        // MARK: ------------ PVMediaCache ------------
        .target(
            name: "PVMediaCache",
            dependencies: [
                "PVSupport",
                "PVLogging",
                "PVHashing",
                "PVLookup",
                "PVPrimitives",
                "PVFileSystem",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        ]),
        // MARK: ------------ PVFileSystem ------------
        .target(
            name: "PVFileSystem",
            dependencies: [
                "PVSupport",
                "PVLogging",
                "PVHashing",
                "PVLookup",
                "PVPrimitives",
                "SwiftCloudDrive",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        ]),
//        // MARK: ------------ DirectoryWatcher ------------
//        .target(
//            name: "DirectoryWatcher",
//            dependencies: [
//                "PVSupport",
//                "PVLogging",
//                "PVHashing",
//                "PVLookup",
//                "PVPrimitives",
//                "Extractor",
//                "PVFileSystem",
//                .product(name: "Perception", package: "swift-perception"),
//                .product(name: "RxCocoa", package: "RxSwift"),
//                .product(name: "RxSwift", package: "RxSwift"),
//                .product(name: "RxRealm", package: "RxRealm"),
//                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
//        ]),
        // MARK: ------------ Extractor ------------
        .target(
            name: "Extractor",
            dependencies: [
                "PVSupport",
                "PLzmaSDK",
                "SWCompression",
                "PVLogging",
                "PVHashing",
                "PVPlists",
                "PVLookup",
                "PVPrimitives",
                .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                .product(name: "PVCoreLoader", package: "PVCoreLoader"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "ZipArchive", package: "ZipArchive"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]),
        // MARK: ------------ Tests ------------
        .testTarget(
            name: "PVLibraryTests",
            dependencies: [
                "PVLibrary",
                "PVLookup",
                "PVPrimitives"
            ]
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
