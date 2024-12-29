// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "PVCoreLoader",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PVCoreLoader",
            targets: ["PVCoreLoader"]),
    ],
    dependencies: [
        .package(path: "../PVCoreBridge/"),
        .package(path: "../PVPlists/"),
        .package(path: "../PVEmulatorCore/"),
        .package(path: "../PVLogging/"),
        .package(path: "../PVSupport/"),

        // MARK: Cores
        .package(path: "../Cores/Atari800/"),
        .package(path: "../Cores/Menafen/"),
        .package(path: "../Cores/PicoDrive/"),
        .package(path: "../Cores/PokeMini/"),
        .package(path: "../Cores/Stella/"),
        .package(path: "../Cores/TGBDual/"),
        .package(path: "../Cores/VirtualJaguar/"),
        .package(path: "../Cores/VisualBoyAdvance-M/"),

        // MARK: Plugins

        // SwiftGenPlugin
        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),

        // MARK: Macros

        // SwiftMacros
        // https://github.com/ShenghaiWang/SwiftMacros?tab=readme-ov-file
        .package(url: "https://github.com/JoeMatt/SwiftMacros.git", branch: "main"),

        // swift-macro-toolkit
        // https://github.com/stackotter/swift-macro-toolkit
//        .package(url: "https://github.com/stackotter/swift-macro-toolkit.git", from: "510.0.0"),
    ],
    targets: [

        // Macro Target: ConditionalOnImportEnumerationMacro
        .macro(
            name: "ConditionalOnImportEnumerationMacro",
            dependencies: [
//                "swift-macro-toolkit.git"
            ],
            path: "Sources/Macros/ConditionalOnImportEnumerationMacro"
        ),

        // Macro Target: CorePlistParserMacro
        .macro(
            name: "CorePlistParserMacro",
            dependencies: [
//                "swift-macro-toolkit.git"
            ],
            path: "Sources/Macros/CorePlistParserMacro"
        ),

        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PVCoreLoader",
            dependencies: [
                "SwiftMacros",
                "PVCoreBridge",
                "PVEmulatorCore",
                "PVLogging",
                "PVSupport",

//                .product(name: "PVAtari800-Dynamic", package: "Atari800"),
//                .product(name: "PVPicoDrive-Dynamic", package: "PicoDrive"),
//                .product(name: "PVPokeMini-Dynamic", package: "PokeMini"),
//                .product(name: "PVStella-Dynamic", package: "Stella"),
//                .product(name: "PVTGBDual-Dynamic", package: "TGBDual"),
//                .product(name: "PVVirtualJaguar-Dynamic", package: "VirtualJaguar"),
//                .product(name: "PVVisualBoyAdvance-Dynamic", package: "VisualBoyAdvance-M")
            ],
            resources: [
                .process("Resources/systems.plist")
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
            ]
        ),

        // Target to wrap test cores
        .target(
            name: "PVCoreEnumerator",
            dependencies: [
                .product(name: "PVAtari800-Dynamic", package: "Atari800"),
                .product(name: "PVPicoDrive-Dynamic", package: "PicoDrive"),
                .product(name: "PVPokeMini-Dynamic", package: "PokeMini"),
                .product(name: "PVStella-Dynamic", package: "Stella"),
                .product(name: "PVTGBDual-Dynamic", package: "TGBDual"),
                .product(name: "PVVirtualJaguar-Dynamic", package: "VirtualJaguar"),
                .product(name: "PVVisualBoyAdvance-Dynamic", package: "VisualBoyAdvance-M")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .testTarget(
            name: "PVCoreLoaderTests",
            dependencies: [
                "PVCoreLoader",
                "PVLogging",
                "PVCoreBridge",
                "PVEmulatorCore",

                "PVCoreEnumerator"
            ])
    ],
    swiftLanguageModes: [.v5, .v6]
)
