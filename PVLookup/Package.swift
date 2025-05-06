// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLookup",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v12),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLookup",
            targets: ["PVLookup"]
        ),
        .library(
            name: "PVLookup-Static",
            type: .static,
            targets: ["PVLookup"]
        ),
        .library(
            name: "PVLookup-Dynamic",
            type: .dynamic,
            targets: ["PVLookup"]
        ),
    ],
    dependencies: [
        .package(path: "../PVLogging"),
        .package(path: "../PVPrimitives"),
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),

        ///
        /// Database
        ///

        .package(url: "https://github.com/stephencelis/SQLite.swift.git", .upToNextMajor(from: "0.15.3")),

        // https://github.com/Lighter-swift/Lighter
        //.package(url: "https://github.com/Lighter-swift/Lighter.git", from: "1.4.4"),
        .package(url: "https://github.com/JoeMatt/Lighter.git", branch: "develop"),

//        .package(url: "https://github.com/JoeMatt/SWCompression.git", branch: "develop"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.18")),

        // Swagger Generation by @Apple
        // https://tinyurl.com/yn3dnbr5
//        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
//        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
//        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
    ],

    targets: [

        // MARK: - Library


        // MARK: - Lookup

        .target(
            name: "PVLookup",
            dependencies: [
                "PVLogging",
                "OpenVGDB",
                "ROMMetadataProvider",
                "PVLookupTypes",
                "libretrodb",
                "ShiraGame",
                "PVPrimitives",
                "TheGamesDB"
            ]
        ),

        // SQLite Wrapper

        .target(
            name: "PVSQLiteDatabase",
            dependencies: [
                "PVLogging",
                .product(name: "SQLite", package: "sqlite.swift"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),

        // MARK:  TheGamesDB

        // https://github.com/OpenVGDB/OpenVGDB/releases

         .target(
             name: "TheGamesDB",
             dependencies: [
                "PVLogging",
                "PVSQLiteDatabase",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
//                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
                "PVLookupTypes",
                "ROMMetadataProvider",
                "PVPrimitives"
             ],
             resources: [
                .copy("Resources/thegamesdb.sqlite.zip")
             ],
             plugins: [
//                 .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
         ]),

        // MARK:  libretrodb

        // https://github.com/avojak/libretrodb-sqlite
        .target(
            name: "libretrodb",
            dependencies: [
                "PVLogging",
                "PVSQLiteDatabase",
                "PVLookupTypes",
                "PVPrimitives",
                "ROMMetadataProvider"
            ],
            resources: [
                .copy("Resources/libretrodb.sqlite.zip"),
            ],
            plugins: [
                // .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
                // .plugin(name: "Enlighter", package: "Lighter")
        ]),

        // MARK:  OpenVGDB

        // https://github.com/OpenVGDB/OpenVGDB/releases
        // Generate from the command line:
        // swift run sqlite2swift Lighter.json OpenVGDB Sources/OpenVGDB/Resources/openvgdb_schema.sql Sources/OpenVGDB/OpenVGDBSQL.swift
        .target(
            name: "OpenVGDB",
            dependencies: [
                "PVLogging",
                "PVSQLiteDatabase",
                "Lighter",
                "PVLookupTypes",
                "PVPrimitives",
                "ROMMetadataProvider"
            ],
            resources: [
                .copy("Resources/openvgdb.sqlite.zip"),
//                .copy("Resources/openvgdb_schema.sql"),
            ],
            plugins: [
                // .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
                // .plugin(name: "Enlighter", package: "Lighter")
        ]),

        // MARK:  ShiraGame

        // https://shiraga.me/
        // Generate from the command line:
        // swift run sqlite2swift Lighter.json ShiraGame Sources/ShiraGame/Resources/shiragame_schema.sql Sources/ShiraGame/ShiraGameSQL.swift
        .target(
            name: "ShiraGame",
            dependencies: [
                "PVLogging",
                "ROMMetadataProvider",
                "PVSQLiteDatabase",
                "PVLookupTypes",
                "PVPrimitives",
                "Lighter"
            ],
            resources: [
//                .copy("Resources/shiragame.sqlite3.7z"),
                .copy("Resources/shiragame.sqlite3.zip"),
//                .copy("Resources/shiragame_schema.sql"),
            ],
            plugins: [
                // .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
                // .plugin(name: "Enlighter", package: "Lighter")
            ]),

        // MARK: ROMMetadataProvider

        .target(
            name: "ROMMetadataProvider",
            dependencies: ["PVLookupTypes", "PVLogging"]
        ),


        // MARK: PVLookupTypes

        .target(
            name: "PVLookupTypes",
            dependencies: [
                "PVLogging",
                "PVPrimitives",
            ]
        ),

        // MARK: PVLookupTests tests

        .testTarget(
            name: "PVLookupTests",
            dependencies: ["PVLookup", "PVLogging"]
        ),
        
        .testTarget(
            name: "TheGamesDBTests",
            dependencies: ["TheGamesDB", "PVLookup", "PVLogging"]
        ),
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
