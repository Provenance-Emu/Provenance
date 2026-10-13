import Foundation
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
    /// Environment variable that must be set (to anything but "" or "0") for `FocusedApp.all` to
    /// include the app. For apps whose package cannot load on a clean checkout: every focused app
    /// shares one generated project, so a package that needs a build artefact would otherwise break
    /// every other app's package resolution.
    public let optInVariable: String?

    public init(
        slug: String,
        title: String,
        cores: [CoreProduct],
        libretro: [String] = [],
        flags: [String] = [],
        optInVariable: String? = nil
    ) {
        self.slug = slug
        self.title = title
        self.cores = cores
        self.libretro = libretro
        self.flags = flags
        self.optInVariable = optInVariable
    }

    /// False when the app is opt-in and its variable is unset.
    public var isEnabled: Bool {
        guard let variable = optInVariable else { return true }
        let value = ProcessInfo.processInfo.environment[variable] ?? ""
        return !value.isEmpty && value != "0"
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
        let coreScripts = allCores.flatMap(\.postScripts)
        return libretroScripts.pre + embed + coreScripts + libretroScripts.post
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
    static let ui = FocusedApp(slug: "ui", title: "UI", cores: [.mGBA, .stella, .snes9x, .fceu, .genesis], flags: [DevSettings.harnessFlag])

    static let thin = FocusedApp(
        slug: "thin",
        title: "Thin",
        cores: [],
        libretro: ["mednafen_psx_hw", "mupen64plus_next", "snes9x", "ppsspp"],
        flags: [DevSettings.harnessFlag]
    )

    // PVAzahar-Dynamic links PVlibAzahar.xcframework, which must be packed before generation:
    // `make dev-azahar` runs `build_slice.py azahar $(DEV_SLICE) --xcframework` first. arm64 only.
    static let azahar = FocusedApp(slug: "azahar", title: "Azahar", cores: [.azahar], flags: [DevSettings.harnessFlag])

    /// Mupen64Plus + its plugin frameworks, all as SwiftPM products (Phase 2 of the core conversion).
    static let n64 = FocusedApp(slug: "n64", title: "N64", cores: [.mupen64Plus], flags: [DevSettings.harnessFlag])

    /// Dolphin as a SwiftPM binary target over `PVlibDolphin.xcodeproj`'s slice cache xcframework.
    /// Device only. Opt in with `TUIST_DEV_DOLPHIN=1`; `make dev-dolphin` produces the xcframework first
    /// and sets it, and CI never does.
    static let dolphin = FocusedApp(slug: "dolphin", title: "Dolphin", cores: [.dolphin], optInVariable: DevSettings.dolphinOptIn)

    /// Every app that exists, enabled or not (the manifest checks validate all of them).
    /// No emulator cores at all: the fastest build of the full UI (library, settings, importer,
    /// skins). Use it for UI/unit-test iteration and as CI's smoke build (Phase 4 of the core
    /// SwiftPM conversion). Games can't launch in it; everything else works.
    static let coreless = FocusedApp(slug: "coreless", title: "Coreless", cores: [], flags: [DevSettings.harnessFlag])

    static let catalog: [FocusedApp] = [.ui, .azahar, .thin, .n64, .dolphin, .coreless]

    /// The apps in the generated project.
    static var all: [FocusedApp] { catalog.filter(\.isEnabled) }
}
