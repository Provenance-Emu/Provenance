import ProjectDescription

public enum DevSettings {
    /// Base xcconfig for the project and every app target (repo-relative).
    public static let xcconfig: Path = .relativeToRoot("Dev/Config/Dev.xcconfig")

    // MARK: Packages

    /// Local packages whose products the app links directly (Provenance-Lite (AppStore) minus cores).
    static let appLocalPackages: [String] = [
        "PVEmulatorCore", "PVCoreAudio", "PVWebServer", "PVLibrary", "PVLogging", "PVThemes",
        "PVPlists", "PVSettings", "PVUI", "PVFeatureFlags", "PVJIT",
    ]

    static let remotePackages: [Package] = [
        .remote(url: "https://github.com/Provenance-Emu/SteamController.git", requirement: .revision("55d2fe0484f4cc5ed3535033af6b0218621e37b2")),
        .remote(url: "https://github.com/ashleymills/Reachability.swift", requirement: .branch("master")),
        .remote(url: "https://github.com/RxSwiftCommunity/RxDataSources.git", requirement: .upToNextMajor(from: "5.0.2")),
        .remote(url: "https://github.com/ZipArchive/ZipArchive.git", requirement: .exact("2.4.3")),
        .remote(url: "https://github.com/jdg/MBProgressHUD.git", requirement: .upToNextMajor(from: "1.2.0")),
        .remote(url: "https://github.com/realm/realm-swift.git", requirement: .upToNextMajor(from: "20.0.3")),
        .remote(url: "https://github.com/sindresorhus/Defaults.git", requirement: .upToNextMajor(from: "9.0.2")),
        .remote(url: "https://github.com/theappcapital/SiriusRating-iOS.git", requirement: .upToNextMajor(from: "1.0.8")),
        .remote(url: "https://github.com/FlineDev/FreemiumKit.git", requirement: .upToNextMajor(from: "1.19.0")),
        .remote(url: "https://github.com/SvenTiigi/WhatsNewKit.git", requirement: .upToNextMajor(from: "2.2.1")),
        .remote(url: "https://github.com/krzyzanowskim/OpenSSL", requirement: .upToNextMajor(from: "3.3.2000")),
    ]

    /// Every local package the apps need, each exactly once (a duplicate `.local(path:)`
    /// fails `tuist generate`). Sorted for stable output.
    public static func localPackagePaths(for apps: [FocusedApp]) -> [String] {
        var paths = Set(appLocalPackages)
        for app in apps {
            for core in app.allCores {
                for link in core.links {
                    if case let .package(path, _) = link { paths.insert(path) }
                }
            }
        }
        return paths.sorted()
    }

    public static func packages(for apps: [FocusedApp]) -> [Package] {
        localPackagePaths(for: apps).map { .local(path: .relativeToRoot($0)) } + remotePackages
    }

    /// Package products every focused app links (Provenance-Lite (AppStore) minus its cores).
    public static let appDependencies: [TargetDependency] = [
        .package(product: "SteamController"),
        .package(product: "Reachability"),
        .package(product: "RxDataSources"),
        .package(product: "ZipArchive"),
        .package(product: "PVEmulatorCore"),
        .package(product: "PVCoreAudio"),
        .package(product: "PVWebServer"),
        .package(product: "PVLibrary"),
        .package(product: "PVLogging"),
        .package(product: "MBProgressHUD"),
        .package(product: "RealmSwift"),
        .package(product: "PVThemes"),
        .package(product: "PVPlists"),
        .package(product: "PVSettings"),
        .package(product: "PVUI"),
        .package(product: "Defaults"),
        .package(product: "SiriusRating", condition: .when([.ios])),
        .package(product: "FreemiumKit"),
        .package(product: "PVFeatureFlags"),
        .package(product: "WhatsNewKit", condition: .when([.ios])),
        .package(product: "OpenSSL"),
        .package(product: "JITManager"),
        .package(product: "PVJIT"),
        .sdk(name: "z", type: .library),
        .sdk(name: "c++", type: .library),
        .sdk(name: "xml2", type: .library),
        .sdk(name: "bz2", type: .library),
    ]

    // MARK: Resources (Provenance-Lite (AppStore) resources phase)

    public static let appResources: ResourceFileElements = [
        .glob(pattern: .relativeToRoot("Provenance/*.lproj/InfoPlist.strings")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/*.lproj/Strings.strings")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/AppStoreAssets-Lite.xcassets")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/Assets-Lite.xcassets")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/ColoredIcons.xcassets")),
        .folderReference(path: .relativeToRoot("Provenance/Resources/Settings.bundle")),
        .glob(pattern: .relativeToRoot("Provenance/licenses.html")),
        .glob(pattern: .relativeToRoot("CONTRIBUTORS.md")),
        .glob(pattern: .relativeToRoot("SYSTEMS.md")),
        .glob(pattern: .relativeToRoot("ProvenanceTV/LaunchImageTV.png"), inclusionCondition: .when([.tvos])),
        .glob(pattern: .relativeToRoot("ProvenanceTV/TVAssets.xcassets"), inclusionCondition: .when([.tvos])),
        .glob(pattern: .relativeToRoot("ProvenanceTV/LaunchScreenTV.storyboard"), inclusionCondition: .when([.tvos])),
        .glob(pattern: .relativeToRoot("ProvenanceTV/Story Boards/*.lproj/*.storyboard"), inclusionCondition: .when([.tvos])),
    ]

    // MARK: Settings

    /// Project-level settings (the shipping project's COMMON block that is not in Build.xcconfig).
    public static let projectSettings: Settings = .settings(
        base: [
            "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
            "ENABLE_BITCODE": "NO",
            "SWIFT_VERSION": "5.0",
        ],
        configurations: [
            .debug(name: .debug, xcconfig: xcconfig),
            .release(name: .release, xcconfig: xcconfig),
        ],
        defaultSettings: .recommended
    )

    /// Target settings for a focused app. Bundle id and product name are per configuration
    /// (a target-level PRODUCT_BUNDLE_IDENTIFIER from `Target.bundleId` would also work, but
    /// per-configuration keeps the iCube pattern and lets Release differ later).
    public static func appSettings(for app: FocusedApp) -> Settings {
        let perConfiguration: SettingsDictionary = [
            "ALPHA_BUNDLE_SUFFIX": .string(".dev.\(app.slug)"),
            "PRODUCT_BUNDLE_IDENTIFIER": "$(ORG_PREFIX).$(PROJECT_NAME:lower)$(ALPHA_BUNDLE_SUFFIX)",
            "PRODUCT_NAME": .string(app.name),
        ]
        var base: SettingsDictionary = [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": .string((["$(inherited)", "PV_DEV"] + app.flags).joined(separator: " ")),
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
            "CODE_SIGN_STYLE": "Automatic",
            "GCC_PREPROCESSOR_DEFINITIONS": ["$(inherited)", "APP_STORE=1", "GL_SILENCE_DEPRECATION=1"],
            "OTHER_SWIFT_FLAGS": ["$(inherited)", "-DAPP_STORE", "-DAPPSTORE"],
            "LD_RUNPATH_SEARCH_PATHS": [
                "$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks",
                "@executable_path/Frameworks/MoltenVK.framework",
            ],
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            // Tuist's .recommended defaults inject the more specific appletvos*/appletvsimulator*
            // keys, which outrank an [sdk=appletv*] override. Pin them (iCube lesson).
            "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=appletvos*]": "App Icon & Top Shelf Image",
            "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=appletvsimulator*]": "App Icon & Top Shelf Image",
            "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.arcade-games",
            "SUPPORTS_MACCATALYST": "NO",
            "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "YES",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "MTL_FAST_MATH": "YES",
            "DEAD_CODE_STRIPPING": "YES",
        ]
        base.merge(app.linkerSettings) { _, new in new }
        return .settings(
            base: base,
            configurations: [
                .debug(name: .debug, settings: perConfiguration, xcconfig: xcconfig),
                .release(name: .release, settings: perConfiguration, xcconfig: xcconfig),
            ],
            defaultSettings: .recommended(excluding: ["ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME"])
        )
    }
}
