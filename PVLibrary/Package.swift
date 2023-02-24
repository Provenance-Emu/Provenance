// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let cxxSettings: [CXXSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
    .headerSearchPath("../PVSupport/Sources/PVSupport/include"),
    .headerSearchPath("../PVEmulatorCore/Sources/PVEmulatorCoreObjC/include")
]

let cSettings: [CSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
    .headerSearchPath("../PVSupport/Sources/PVSupport/include"),
    .headerSearchPath("../PVEmulatorCore/Sources/PVEmulatorCoreObjC/include")
]

let unsafeFlags: SwiftSetting = .unsafeFlags([
//    "-enable-experimental-cxx-interop", // Note, this breaks a bunch of Swift OptionSet and Enums for some reason
    "-enable-objc-interop"
    //    "-Xfrontend", "-enable-experimental-cxx-interop",
    //    "-Xfrontend", "-enable-experimental-cxx-interop-in-clang-header"
    //    "-enable-experimental-cxx-interop-in-clang-header",
    //    "-Xfrontend", "-enable-cxx-interop",
    //    "-Xfrontend", "-Xcc",
    //    "-enable-cxx-interop",
    //    "-Xfrontend", "-enable-cxx-interop",
    //    "-Xfrontend", "-validate-tbd-against-ir=none",
    //    "-I", "Sources/CXX/include",
    //    "-I", "\(sdkRoot)/usr/include",
    //    "-I", "\(cPath)",
    //    "-lc++",
    //    "-Xfrontend", "-disable-implicit-concurrency-module-import",
    //    "-Xcc", "-nostdinc++"
])

let swiftSettings: [SwiftSetting] = [
    .define("LIBRETRO"),
    unsafeFlags
]

let linkerSettings: [LinkerSetting] = [
    .linkedFramework("Foundation"),
    .linkedFramework("CoreGraphics"),
    .linkedFramework("CoreSpotlight"),
    .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
    .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .watchOS])),
    .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
]

let package = Package(
    name: "PVLibrary",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLibrary",
            targets: ["PVLibrary"]),
        .library(
            name: "PVLibrary-Static",
            type: .static,
            targets: ["PVLibrary"]),
        .library(
            name: "PVLibrary-Dynamic",
            type: .dynamic,
            targets: ["PVLibrary"]),

            .library(
                name: "PVHashing",
                targets: ["PVHashing"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            name: "PVSupport",
            path: "../PVSupport"),
        .package(
            name: "PVLogging",
            path: "../PVLogging"),
        .package(
            name: "PVObjCUtils",
            path: "../PVObjCUtils"),
        .package(
            name: "PVEmulatorCore",
            path: "../PVEmulatorCore"),
        .package(
            url: "https://github.com/ReactiveX/RxSwift",
            .upToNextMajor(from: "6.5.0")),
        .package(
            url: "https://github.com/RxSwiftCommunity/RxRealm",
            .upToNextMajor(from: "5.0.5")),
        .package(
            url: "https://github.com/groue/GRDB.swift.git",
            .upToNextMajor(from: "6.6.0")),
        .package(
            url: "https://github.com/stephencelis/SQLite.swift",
            .upToNextMajor(from: "0.14.1")),
        .package(
            url: "https://github.com/ZipArchive/ZipArchive",
            .upToNextMinor(from: "2.4.3")),
        .package(
            url: "https://github.com/OlehKulykov/PLzmaSDK.git",
            revision: "1.2.5"),
        .package(
            url: "https://github.com/tsolomko/SWCompression.git",
            .upToNextMinor(from: "4.8.4")),
        .package(
            url: "https://github.com/JoeMatt/Checksum.git",
            from: "1.1.1")
    ],
    targets: [
        .target(
            name: "PVLibrary",
            dependencies: [
                "PVSupport",
                "PLzmaSDK",
                "SWCompression",
                "PVLogging",
                "Checksum",
                "PVHashing", // Use the objC or Swift version, when it's tested @JoeMatt
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "PVEmulatorCore", package: "PVEmulatorCore"),
                //.product(name: "PVEmulatorCoreObjC", package: "PVEmulatorCore"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRealm", package: "RxRealm"),
                .product(name: "ZipArchive", package: "ZipArchive")
            ],
            exclude: [
                "Info.plist"
            ],
            resources: [
                .copy("Resources/cheatbase.sqlite"),
                .copy("Resources/openvgdb.sqlite"),
                .copy("Resources/systems.plist"),
                //                .process("Resources/")
            ],
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings
        ),

        .target(
            name: "PVHashing",
            dependencies: ["PVObjCUtils", "PVSupport"]
        ),

        .target(
            name: "PVHashingSwift",
            dependencies: ["PVObjCUtils", "PVSupport"]
        ),
        
        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLibraryTests",
            dependencies: ["PVLibrary"],
            path: "Tests")
    ],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
