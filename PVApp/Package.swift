// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let localPackages = [
    "PVPatreon",
    "PVLibrary",
    "PVLibRetro",
    ]

var dependencies: [PackageDescription.Package.Dependency] = localPackages.map {
    return PackageDescription.Package.Dependency.package(path: "../\($0)")
}

let package = Package(
    name: "PVApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVApp",
            targets: ["PVApp"]),
//        .library(
//            name: "PVApp-Dynamic",
//            type: .dynamic,
//            targets: ["PVApp"]),
//        .library(
//            name: "PVApp-Static",
//            type: .static,
//            targets: ["PVApp"]),
//        .library(
//            name: "PVApp-tvOS",
//            targets: ["PVApp-tvOS"]),
//        .library(
//            name: "PVApp-tvOS-Dynamic",
//            type: .dynamic,
//            targets: ["PVApp-tvOS"]),
//        .library(
//            name: "PVApp-tvOS-Static",
//            type: .static,
//            targets: ["PVApp-tvOS"])
    ],
    dependencies: [
//        .package(name: "PVAudio",
//                 path: "../PVAudio"),
//        .package(name: "PVSupport",
//                 path: "../PVSupport"),
        .package(name: "PVPatreon",
                 path: "../PVPatreon"),
        .package(name: "PVLibrary",
                 path: "../PVLibrary"),
//        .package(name: "PVEmulatorCore",
//                 path: "../PVEmulatorCore"),
        .package(name: "PVLibRetro",
                 path: "../PVLibRetro"),
//        .package(name: "PVLogging",
//                 path: "../PVLogging"),
        .package(
            url: "https://github.com/Provenance-Emu/SteamController.git",
            branch: "master"),
        .package(
            url: "https://github.com/microsoft/appcenter-sdk-apple.git",
            from: "5.0.0"),
        .package(
            url: "https://github.com/SideStore/AltKit",
            branch: "main"),
        .package(
            url: "https://github.com/siteline/SwiftUI-Introspect.git",
            branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "PVApp",
            dependencies: [
                "AltKit",
//                "PVAudio",
//                "PVEmulatorCore",
                "PVLibrary",
                "PVLibRetro",
//                "PVLogging",
                "PVPatreon",
//                "PVSupport",
                "SteamController",
                .product(name: "Introspect", package: "SwiftUI-Introspect"),
                .product(name: "AppCenterAnalytics", package: "appcenter-sdk-apple"),
                .product(name: "AppCenterCrashes", package: "appcenter-sdk-apple")
            ],
            // exclude: [
            //     "Info.plist"
            // ],
            resources: [
                .process("Resources/")
            ],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("GameController"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("CoreHaptics"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreTelephony"),
            ]
        ),

//        .target(
//            name: "PVApp-tvOS",
//            dependencies: [
//                "AltKit",
//                "PVAudio",
//                "PVEmulatorCore",
//                "PVLibrary",
//                "PVLibRetro",
//                "PVLogging",
//                "PVPatreon",
//                "PVSupport",
//                "SteamController",
//                .product(name: "Introspect", package: "SwiftUI-Introspect"),
//                .product(name: "AppCenterAnalytics", package: "appcenter-sdk-apple"),
//                .product(name: "AppCenterCrashes", package: "appcenter-sdk-apple")
//            ],
//            // exclude: [
//            //     "Info.plist"
//            // ],
//            resources: [
//                .process("Resources/")
//            ],
//            linkerSettings: [
//                .linkedFramework("UIKit"),
//                .linkedFramework("GameController"),
//                .linkedFramework("CoreMotion"),
//                .linkedFramework("CoreHaptics"),
//                .linkedFramework("CoreBluetooth"),
//                .linkedFramework("CoreLocation"),
//                .linkedFramework("CoreTelephony"),
//            ]
//        ),
//
//        .target(
//            name: "PVApp-ObjC",
//            dependencies: [
//                "AltKit",
//                "PVAudio",
//                "PVEmulatorCore",
//                "PVLibrary",
//                "PVLibRetro",
//                "PVLogging",
//                "PVPatreon",
//                "PVSupport",
//                "SteamController",
//                .product(name: "Introspect", package: "SwiftUI-Introspect"),
//                .product(name: "AppCenterAnalytics", package: "appcenter-sdk-apple"),
//                .product(name: "AppCenterCrashes", package: "appcenter-sdk-apple")
//            ],
//            // exclude: [
//            //     "Info.plist"
//            // ],
//            resources: [
//                .process("Resources/")
//            ],
//            linkerSettings: [
//                .linkedFramework("UIKit"),
//                .linkedFramework("GameController"),
//                .linkedFramework("CoreMotion"),
//                .linkedFramework("CoreHaptics"),
//                .linkedFramework("CoreBluetooth"),
//                .linkedFramework("CoreLocation"),
//                .linkedFramework("CoreTelephony"),
//            ]
//        ),

        // MARK: SwiftPM tests
//        .testTarget(
//            name: "PVAppTests",
//            dependencies: ["PVApp"]
//        )
    ],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
