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

    /// OTHER_LDFLAGS for `project` links (empty until Task 3).
    var linkerSettings: SettingsDictionary { [:] }

    var coreDependencies: [TargetDependency] {
        allCores.flatMap { core -> [TargetDependency] in
            core.links.compactMap { link -> TargetDependency? in
                switch link {
                case let .package(_, product):
                    return .package(product: product, condition: .when(core.platforms))
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
            scripts: [],
            dependencies: DevSettings.appDependencies + coreDependencies,
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
    static let ui = FocusedApp(slug: "ui", title: "UI", cores: [.mGBA, .stella], flags: ["PV_DEV_HARNESS"])

    static let all: [FocusedApp] = [.ui]
}
