import ProjectDescription

/// A small app target that embeds only the cores it lists. Add a target by appending
/// one literal to `FocusedApp.all`.
public struct FocusedApp {
    /// Lowercase id: bundle suffix `.dev.<slug>`.
    public let slug: String
    /// Name suffix: target and scheme `Provenance-Dev-<title>`.
    public let title: String
    public let cores: [CoreProduct]
    /// cores.yml names whose buildbot dylibs the app embeds.
    public let libretro: [String]
    /// SWIFT_ACTIVE_COMPILATION_CONDITIONS additions.
    public let flags: [String]

    public init(slug: String, title: String, cores: [CoreProduct], libretro: [String] = [], flags: [String] = []) {
        self.slug = slug
        self.title = title
        self.cores = cores
        self.libretro = libretro
        self.flags = flags
    }

    public var name: String { "Provenance-Dev-\(title)" }

    /// `cores` plus the non-core products every app embeds.
    public var allCores: [CoreProduct] { CoreProduct.nonCore + cores }

    /// Products of `project` links, in table order, without duplicates.
    var projectProducts: [(product: String, platforms: Set<PlatformFilter>)] {
        var seen = Set<String>()
        var result: [(product: String, platforms: Set<PlatformFilter>)] = []
        for core in allCores {
            for link in core.links {
                if case let .project(_, _, product) = link, seen.insert(product).inserted {
                    result.append((product, core.platforms))
                }
            }
        }
        return result
    }

    /// `-framework <Product>` per project link. Platform-limited rows get an sdk-conditioned key.
    var linkerSettings: SettingsDictionary {
        func flags(_ filter: (Set<PlatformFilter>) -> Bool) -> [String] {
            projectProducts.filter { filter($0.platforms) }.flatMap { ["-framework", $0.product] }
        }
        let shared = ["$(inherited)"] + flags { $0.contains(.ios) && $0.contains(.tvos) }
        var settings: SettingsDictionary = ["OTHER_LDFLAGS": .array(shared)]
        // A conditional key replaces the unconditional one for that SDK, so it repeats the shared flags.
        let iosOnly = flags { $0.contains(.ios) && !$0.contains(.tvos) }
        let tvosOnly = flags { $0.contains(.tvos) && !$0.contains(.ios) }
        if !iosOnly.isEmpty {
            settings["OTHER_LDFLAGS[sdk=iphone*]"] = .array(shared + iosOnly)
        }
        if !tvosOnly.isEmpty {
            settings["OTHER_LDFLAGS[sdk=appletv*]"] = .array(shared + tvosOnly)
        }
        return settings
    }

    var scripts: [TargetScript] {
        let libretroScripts = LibretroCores.scripts(slug: slug, names: libretro)
        let products = projectProducts.map(\.product)
        let embed = products.isEmpty ? [] : [DevSettings.embedProjectFrameworksScript(products: products)]
        // Post order: embed vendored frameworks, then wrap libretro dylibs, then validate.
        return libretroScripts.pre + embed + libretroScripts.post
    }

    /// Vendored .xcodeproj files the workspace must contain for these apps.
    public static func workspaceProjects(for apps: [FocusedApp]) -> [String] {
        var paths = Set<String>()
        for app in apps {
            for core in app.allCores {
                for link in core.links {
                    if case let .project(path, _, _) = link { paths.insert(path) }
                }
            }
        }
        return paths.sorted()
    }

    var coreDependencies: [TargetDependency] {
        allCores.flatMap { core -> [TargetDependency] in
            core.links.compactMap { link -> TargetDependency? in
                switch link {
                case let .package(_, product):
                    // MoltenVK is already embedded through its dependents; embedding it again
                    // fails with "Unexpected duplicate tasks".
                    return .package(product: product, type: product == "MoltenVK" ? .runtime : .runtimeEmbedded, condition: .when(core.platforms))
                case let .prebuilt(path):
                    return path.hasSuffix(".xcframework")
                        ? .xcframework(path: .relativeToRoot(path), condition: .when(core.platforms))
                        : .framework(path: .relativeToRoot(path), condition: .when(core.platforms))
                case .project:
                    return nil
                }
            }
        }
    }

    public func target() -> Target {
        .target(
            name: name,
            destinations: [.iPhone, .iPad, .appleTv, .macWithiPadDesign],
            product: .app,
            productName: name,
            // Placeholder: PRODUCT_BUNDLE_IDENTIFIER is set per configuration in DevSettings.
            bundleId: "org.provenance-emu.provenance.dev.\(slug)",
            deploymentTargets: .multiplatform(iOS: "17.0", tvOS: "17.0"),
            infoPlist: .file(path: .relativeToRoot("Provenance/Provenance-Lite (AppStore)-Info.plist")),
            sources: [.glob(.relativeToRoot("Provenance/Main UI/**/*.swift"))],
            resources: DevSettings.appResources,
            entitlements: nil,
            scripts: scripts,
            dependencies: DevSettings.appDependencies + coreDependencies
                + (flags.contains(DevSettings.harnessFlag) ? [.package(product: "PVDevHarness")] : []),
            settings: DevSettings.appSettings(for: self)
        )
    }

    public func scheme() -> Scheme {
        .scheme(
            name: name,
            shared: true,
            buildAction: .buildAction(targets: [.target(name)]),
            runAction: .runAction(configuration: .debug, executable: .target(name)),
            archiveAction: .archiveAction(configuration: .release)
        )
    }
}

public extension FocusedApp {
    static let ui = FocusedApp(slug: "ui", title: "UI", cores: [.mGBA, .stella, .snes9x], flags: [DevSettings.harnessFlag])

    static let thin = FocusedApp(
        slug: "thin",
        title: "Thin",
        cores: [],
        libretro: ["mednafen_psx_hw", "mupen64plus_next", "snes9x", "ppsspp"],
        flags: [DevSettings.harnessFlag]
    )

    // PVAzahar depends on its BuildPVlibAzahar aggregate inside PVAzahar.xcodeproj, so the
    // implicit dependency on PVAzahar also builds (or cache-links) the PVlibAzahar slice.
    static let azahar = FocusedApp(slug: "azahar", title: "Azahar", cores: [.azahar], flags: [DevSettings.harnessFlag])

    static let all: [FocusedApp] = [.ui, .azahar, .thin]
}
