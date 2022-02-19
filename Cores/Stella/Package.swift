// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVStella",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        // .watchOS(.v7),
        // .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        // .library(
        //     name: "PVStella",
        //     targets: ["PVStella"]),
        .library(
            name: "StellaCore",
            targets: ["StellaCore"]),
    ],
    dependencies: [
    ],
    targets: [

        .target(
            name: "StellaCore",
            dependencies: [],
            path: "PVStella/Stella/StellaCore",
            exclude: ["src/stella/stella.cpp"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("src"),
                .headerSearchPath("src/stella/cart"),
                .headerSearchPath("src/stella/input"),
                .headerSearchPath("src/stella/properties"),
                .headerSearchPath("src/stella/system"),
                .headerSearchPath("src/stella/utility")
            ]
        ),

                // .flag("-Wno-deprecated-declarations"),
                // .flag("-fno-strict-overflow"),
                // .flag("-ffast-math"),
                // .flag("-funroll-loops"),
                // .flag("-fPIC"),
                // .flag("-DLSB_FIRST"),
                // .flag("-DHAVE_MKDIR"),
                // .flag("-DSIZEOF_DOUBLE=8"),
                // .flag("-DPSS_STYLE=1"),
                // .flag("-DMPC_FIXED_POINT"),
                // .flag("-DARCH_X86"),
                // .flag("-DWANT_STELLA_EMU"),
                // .flag("-DSTDC_HEADERS"),
                // .flag("-DHAVE_INTTYPES"),
                // .flag("-DKeyboard=StellaKeyboard"),
        .target(
            name: "PVStella",
            dependencies: [
                "StellaCore",
                // "PVSupportObjC",
                // "PVAudio",
                // "PVLogging"
            ],
            path: "PVStella/Stella/",
            sources: [
                "PVStellaGameCore.mm"
            ],
            resources: [
                .process("../../Stella/Core.plist")
            ],
            publicHeadersPath: "Public Headers"),

        // MARK: SwiftPM tests
        // .testTarget(
        //     name: "PVStellaTests",
        //     dependencies: ["PVStella"]),
    ],
    cxxLanguageStandard: .gnucxx11
)
