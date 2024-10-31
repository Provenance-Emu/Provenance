// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let USE_DISPLAY_LINK = false

let package = Package(
    name: "PVUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PVUI",
            targets: ["PVUIKit", "PVSwiftUI"]),
    ],
    dependencies: [
        .package(path: "../PVAudio"),
        .package(path: "../PVCoreAudio"),
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVEmulatorCore"),
        .package(path: "../PVLibrary"),
        .package(path: "../PVLogging"),
        .package(path: "../PVSupport"),
        .package(path: "../PVThemes"),
        .package(path: "../PVWebServer"),
        .package(url: "https://github.com/ashleymills/Reachability.swift.git", branch: "master"),
        .package(url: "https://github.com/RxSwiftCommunity/RxDataSources.git", from: "5.0.2"),
        .package(url: "https://github.com/jdg/MBProgressHUD.git", from: "1.2.0"),
//        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
        /// https://github.com/DimaRU/BuildEnvironment
        .package(url: "https://github.com/DimaRU/BuildEnvironment.git", from: "1.0.0"),
//        .package(path: "../PackageBuildInfo")
        /// https://github.com/DimaRU/PackageBuildInfo
        .package(url: "https://github.com/JoeMatt/PackageBuildInfo", branch: "master"),
        /// FreemiumKit
        .package(url: "https://github.com/FlineDev/FreemiumKit.git", from: "1.11.0"),
        /// SwiftUIKit
        .package(url: "https://github.com/danielsaidi/SwiftUIKit.git", from: "5.0.0"),
        /// SwiftUIX
        /// https://github.com/SwiftUIX/SwiftUIX/wiki
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", from: "0.2.3")
        
        /// https://swiftpackageindex.com/SvenTiigi/WhatsNewKit
//        .package(url: "https://github.com/SvenTiigi/WhatsNewKit.git", from: "2.2.1")
    ],
    targets: [
        
        // MARK: Common - Base
        /// The main target for the base framework.
        /// This target is available on all platforms.
        /// This target is the base for all other targets.
        .target(
            name: "PVUIBase",
            dependencies: [
                "PVLogging",
                "PVCoreBridge",
                "PVEmulatorCore",
                "PVSupport",
                "PVLibrary",
                "PVThemes",
                "PVWebServer",
                "PVUIObjC",
                "FreemiumKit",
                .byNameItem(name: "MBProgressHUD", condition: .when(platforms: [.iOS, .macCatalyst, .tvOS, .watchOS])),
                .byNameItem(name: "PVUI_AppKit", condition: .when(platforms: [.macOS])),
                .byNameItem(name: "PVUI_TV", condition: .when(platforms: [.tvOS])),
                .byNameItem(name: "PVUI_IOS", condition: .when(platforms: [.iOS, .macCatalyst, .visionOS])),
//                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            resources: [
                .copy("Resources/Shaders/"),
                .copy("Resources/PrivacyInfo.xcprivacy"),
                .process("Resources/SystemIcons.xcassets"),
                .process("Resources/Assets.xcassets")
            ],
            cSettings: [
                .define("GL_SILENCE_DEPRECATION", to: "1"),
                .define("GLES_SILENCE_DEPRECATION", to: "1"),
                .define("CI_SILENCE_GL_DEPRECATION", to: "1")
            ],
            swiftSettings: [
                .define("USE_OPENGL", .when(platforms: [.macCatalyst, .macOS])),
                .define("USE_OPENGLES", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("USE_METAL", .when(platforms: [.macCatalyst, .macOS])),
                .define("USE_EFFECT", .when(platforms: [.iOS, .tvOS, .visionOS, .macCatalyst])),
                .define("GL_SILENCE_DEPRECATION"),
                .define("GLES_SILENCE_DEPRECATION"),
                .define("CI_SILENCE_GL_DEPRECATION")
            ] +
            (USE_DISPLAY_LINK ? [.define("USE_DISPLAY_LINK")] : []),
            plugins: [
                .plugin(name: "PackageBuildInfoPlugin", package: "PackageBuildInfo"),
                .plugin(name: "BuildEnvPlugin", package: "BuildEnvironment")
            ]
        ),
        
        .testTarget(
            name: "PVUIBaseTests",
            dependencies: [
                "PVUIBase",
            ]
        ),

        // MARK: Common - UIKit
        /// The main target for the UIKit framework.
        /// This conditionally includes resources for each platform.
        /// This target is only available on iOS, tvOS, visionOS, and macCatalyst.
        .target(
            name: "PVUIKit",
            dependencies: [
                "PVAudio",
                "PVCoreAudio",
                "PVUIBase",
                "PVLogging",
                "PVCoreBridge",
                "PVEmulatorCore",
                "PVSupport",
                "PVLibrary",
                "PVThemes",
                "PVWebServer",
                "MBProgressHUD",
                "FreemiumKit",
                .product(name: "Reachability", package: "reachability.swift"),
                "RxDataSources",
//                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            resources: [
                .copy("Resources/Shaders/"),
                .copy("Resources/PrivacyInfo.xcprivacy")
            ],
            cSettings: [
                .define("GL_SILENCE_DEPRECATION", to: "1"),
                .define("GLES_SILENCE_DEPRECATION", to: "1"),
                .define("CI_SILENCE_GL_DEPRECATION", to: "1")
            ],
            swiftSettings: [
                .define("USE_OPENGL", .when(platforms: [.macCatalyst, .macOS])),
                .define("USE_OPENGLES", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .define("USE_METAL", .when(platforms: [.macCatalyst, .macOS])),
                .define("USE_EFFECT", .when(platforms: [.iOS, .tvOS, .visionOS, .macCatalyst])),
                .define("GL_SILENCE_DEPRECATION"),
                .define("GLES_SILENCE_DEPRECATION"),
                .define("CI_SILENCE_GL_DEPRECATION")
            ]
        ),
        
        .testTarget(
            name: "PVUIKitTests",
            dependencies: [
                "PVUIKit",
            ]
        ),
        
        // MARK: Common - SwiftUI
        /// A small amount of elements are shared between UIKit and SwiftUI
        .target(
            name: "PVSwiftUI",
            dependencies: [
                "PVUIBase",
                "PVUIKit",
                "PVLogging",
                "PVCoreBridge",
                "PVEmulatorCore",
                "PVSupport",
                "PVLibrary",
                "PVThemes",
                "MBProgressHUD",
                "FreemiumKit"
            ]
        ),
        
        .testTarget(
            name: "PVSwiftUITests",
            dependencies: [
                "PVSwiftUI",
            ]
        ),
        
        // MARK: iOS
        /// Allows for conditional use of resources that can only be included with iOS
        /// compatible targets.
        /// This target is only available on iOS.
        .target(
            name: "PVUI_IOS",
            dependencies: [
//                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            resources: [
                .process("Resources/StoryBoards/"),
                .process("Resources/XIBs/")
            ]
        ),
        
        .testTarget(
            name: "PVUI_IOSTests",
            dependencies: [
                "PVUI_IOS"
            ]
        ),
        
        // MARK: TVOS
        /// Allows for conditional use of resources that can only be included with tvO
        /// compatible targets.
        /// This target is only available on tvOS.
        .target(
            name: "PVUI_TV",
            dependencies: [
                "PVLibrary",
                "PVSupport",
                "RxDataSources"
//                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            resources: [
                .process("Resources/StoryBoards/"),
                .process("Resources/XIBs"),
                .process("Resources/TVAssets.xcassets"),
                .process("Resources/LaunchImageTV.png")
            ]
        ),
        
        .testTarget(
            name: "PVUI_TVTests",
            dependencies: [
                "PVUI_TV"
            ]
        ),
        
        // MARK: AppKit
        /// Allows for conditional use of resources that can only be included with iOS
        /// compatible targets.
        /// This target is only available on iOS.
        .target(
            name: "PVUI_AppKit",
            dependencies: [
//                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        
        .testTarget(
            name: "PVUI_AppKitTests",
            dependencies: [
                "PVUI_AppKit"
            ]
        ),
        
        // MARK: ObjC for very basic hack to GLES
        .target(
            name: "PVUIObjC"
        ),

    ],
    swiftLanguageModes: [.v5]
)
