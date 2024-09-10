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
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLibrary",
            targets: ["PVLibrary", "PVLookup"]
        ),
        .library(
            name: "PVLibrary-Static",
            type: .static,
            targets: ["PVLibrary", "PVLookup"]
        ),
        .library(
            name: "PVLibrary-Dynamic",
            type: .dynamic,
            targets: ["PVLibrary", "PVLookup"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            name: "PVSupport",
            path: "../PVSupport"
        ),
        .package(
            name: "PVLogging",
            path: "../PVLogging"
        ),
        .package(
            name: "PVHashing",
            path: "../PVHashing"
        ),
        .package(
            name: "PVEmulatorCore",
            path: "../PVEmulatorCore"
        ),
        .package(
            name: "PVCoreLoader",
            path: "../PVCoreLoader"
        ),
        .package(path: "../PVPlists"),
        .package(
            url: "https://github.com/ReactiveX/RxSwift.git",
            .upToNextMajor(from: "6.7.1")
        ),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxRealm.git",
            .upToNextMajor(from: "5.1.0")
        ),
        //        .package(
        //            url: "https://github.com/groue/GRDB.swift.git",
        //            .upToNextMajor(from: "6.6.0")
        //        ),
            .package(
                url: "https://github.com/stephencelis/SQLite.swift.git",
                .upToNextMajor(from: "0.15.3")
            ),
        .package(
            url: "https://github.com/ZipArchive/ZipArchive.git",
            exact: "2.4.3"
        ),
        .package(
            url: "https://github.com/OlehKulykov/PLzmaSDK.git",
            revision: "1.2.5"
        ),
        .package(
            url: "https://github.com/tsolomko/SWCompression.git",
            .upToNextMinor(from: "4.8.4")
        ),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
        
        // Swagger Generation by @Apple
        // https://swiftpackageindex.com/apple/swift-openapi-generator/1.3.0/tutorials/swift-openapi-generator/clientswiftpm
        
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0")
    ],
    
    targets: [
        
        // MARK: - Library
        
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
                "PVLibraryPrimitives",
                .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                .product(name: "PVCoreLoader", package: "PVCoreLoader"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "ZipArchive", package: "ZipArchive"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            resources: [
                .process("Resources/cheatbase.sqlite"),
                .process("Resources/systems.plist")
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]),
        
        // MARK: - Library Primitives
        
        .target(
            name: "PVLibraryPrimitives",
            dependencies: ["PVSupport", "PVLogging", "PVHashing"]
        ),
        
        // MARK: - Lookup
        
        .target(
            name: "PVLookup",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                "PVLogging",
                "OpenVGDB",
                "ShiraGame",
                "TheGamesDB"
        ]),
        
        // SQLite Wrapper
        
        .target(
            name: "PVSQLiteDatabase"
        ),
        
        // MARK:  TheGamesDB
        
        // https://github.com/OpenVGDB/OpenVGDB/releases
        
        .target(
            name: "TheGamesDB",
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
        ]),

        // MARK:  OpenVGDB
        
        // https://github.com/OpenVGDB/OpenVGDB/releases
        
        .target(
            name: "OpenVGDB",
            dependencies: ["PVSQLiteDatabase"],
            resources: [
                .process("Resources/openvgdb.sqlite"),
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
        ]),
        
        // MARK:  ShiraGame

        // https://shiraga.me/
        
        .target(
            name: "ShiraGame",
            dependencies: ["PVSQLiteDatabase"],
            resources: [
                .process("Resources/shiragame.sqlite3"),
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
        ]),
        
        // MARK: PVLibraryTests tests
        
        .testTarget(
            name: "PVLibraryTests",
            dependencies: ["PVLibrary"]
        ),
        
        // MARK: PVLookupTests tests

        .testTarget(
            name: "PVLookupTests",
            dependencies: ["PVLookup"]
        )
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
