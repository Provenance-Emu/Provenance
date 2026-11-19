//
//  ProvenanceBezels.swift
//  PVUI
//
//  Provenance's side of the shared TV bezel package (SkinKitBezels): where its choices are
//  stored, where its files live, and how a TV becomes a shader of the app's library.
//

import Combine
import Defaults
import Foundation
import PVFileSystem
import PVLogging
import PVSettings
import PVShaders
import PVSystems
import SkinKitBezels

// MARK: - Stored choices

public extension Defaults.Keys {
    /// The TV drawn around the picture, on the device and on an external display: a `TVBezel`
    /// id, `ExternalDisplayBezelRules.noBezelID` for none, or `automaticBezelID` (the default)
    /// to go by the game's system.
    static let externalDisplayBezel = Key<String>("externalDisplayBezel", default: ExternalDisplayBezelRules.automaticBezelID)

    /// Use the TV that suits the game's system, when one does, instead of the chosen one.
    static let externalDisplayBezelMatchesSystem = Key<Bool>("externalDisplayBezelMatchesSystem", default: true)

    /// The picture lights the room around the TV. Off keeps the reflections and costs less GPU time.
    /// `nil` (never set) goes by the device: see `ExternalDisplayBezelRules.lightsRoom`.
    static let externalDisplayBezelLightsRoom = Key<Bool?>("externalDisplayBezelLightsRoom", default: nil)

    /// Show artwork made for the running game around the picture, downloaded from The Bezel
    /// Project the first time the game is played.
    static let externalDisplayGameBezels = Key<Bool>("externalDisplayGameBezels", default: false)

    /// Which of The Bezel Project's two families of artwork is browsed and downloaded.
    static let externalDisplayBezelProjectStyle = Key<BezelProjectStyle>("externalDisplayBezelProjectStyle", default: .gameArt)

    /// TVs pinned to single games: game MD5 to `TVBezel` id (`ExternalDisplayBezelRules.noBezelID` for none).
    static let externalDisplayBezelByGame = Key<[String: String]>("externalDisplayBezelByGame", default: [:])
}

extension BezelProjectStyle: @retroactive Defaults.Serializable, @retroactive UserDefaultsRepresentable {}

/// The shared package's settings, kept in Provenance's own `Defaults` keys.
final class DefaultsBezelSettings: BezelSettingsStore, @unchecked Sendable {
    static let shared = DefaultsBezelSettings()

    private var observation: Task<Void, Never>?

    private init() {
        // A change made anywhere (a settings page, iCloud) reaches the package's open views.
        observation = Task { [weak self] in
            for await _ in Defaults.updates([.externalDisplayBezel, .externalDisplayBezelMatchesSystem,
                                             .externalDisplayBezelLightsRoom, .externalDisplayGameBezels,
                                             .externalDisplayBezelProjectStyle, .externalDisplayBezelByGame],
                                            initial: false) {
                self?.notifyChanged()
            }
        }
    }

    var chosenBezel: String {
        get { Defaults[.externalDisplayBezel] }
        set { Defaults[.externalDisplayBezel] = newValue }
    }

    var matchesSystem: Bool {
        get { Defaults[.externalDisplayBezelMatchesSystem] }
        set { Defaults[.externalDisplayBezelMatchesSystem] = newValue }
    }

    var lightsRoom: Bool? {
        get { Defaults[.externalDisplayBezelLightsRoom] }
        set { Defaults[.externalDisplayBezelLightsRoom] = newValue }
    }

    var showsGameArtwork: Bool {
        get { Defaults[.externalDisplayGameBezels] }
        set { Defaults[.externalDisplayGameBezels] = newValue }
    }

    var bezelProjectStyle: BezelProjectStyle {
        get { Defaults[.externalDisplayBezelProjectStyle] }
        set { Defaults[.externalDisplayBezelProjectStyle] = newValue }
    }

    var pinnedBezels: [String: String] {
        get { Defaults[.externalDisplayBezelByGame] }
        set { Defaults[.externalDisplayBezelByGame] = newValue }
    }
}

// MARK: - Environment

/// Tells the shared package where Provenance keeps things.
public enum ProvenanceBezels {

    /// The package's messages are forwarded on a queue of their own: PVLogging's `log()` is
    /// too deep to call at the bottom of a download on a Swift-concurrency thread.
    private static let logQueue = DispatchQueue(label: "org.provenance-emu.BezelLog", qos: .utility)

    private static let configured: Void = {
        BezelEnvironment.current = BezelEnvironment(
            libraryRootURL: URL.documentsPath.appendingPathComponent(TVBezelLibrary.folderName, isDirectory: true),
            cacheURL: URL.cachesPath.appendingPathComponent("BezelProject", isDirectory: true),
            userAgent: "Provenance",
            settings: DefaultsBezelSettings.shared,
            systems: {
                SystemIdentifier.allCases.map { .init(id: $0.rawValue, name: $0.fullName, shortName: $0.systemName) }
            },
            hasShaderPreset: { ShaderCatalog.shared.entry(for: ShaderID(rawValue: $0)) != nil })
        let queue = logQueue
        BezelLog.handler = { level, message in
            queue.async {
                switch level {
                case .info: ILOG(message)
                case .warning: WLOG(message)
                case .error: ELOG(message)
                }
            }
        }
    }()

    /// Call before the first use of the package: its library and catalogue read the
    /// environment once. Cheap to call again.
    public static func configure() { _ = configured }
}

// MARK: - Shaders

extension TVBezel.Look {
    var shaderID: ShaderID { ShaderID(rawValue: shader) }
}

extension TVBezel {
    /// The standalone preset of a shader-only TV.
    var presetShaderID: ShaderID? { presetID.map(ShaderID.init(rawValue:)) }
}

extension TVBezelScene {
    /// The scene's preset in Provenance's shader library, with this TV's values. `nil` when
    /// the library does not have the preset.
    func resolvedShader(catalog: ShaderCatalog = .shared) -> ResolvedShader? {
        guard let entry = catalog.entry(for: ShaderID(rawValue: presetID)) else { return nil }
        // The values never change for a key, so any revision does: a new scene is a new load.
        return ResolvedShader(entry: entry, values: values, revision: key.hashValue)
    }

    /// The cabinet and room, as the preset's background texture.
    var textures: ShaderTextureOverrides? {
        borderPNG.map { ShaderTextureOverrides(key: key, textures: [TVBezelShader.borderTextureName: $0]) }
    }
}

extension TVBezelShader {
    /// Parameter names filters use to switch their own screen curvature on. Lower-cased.
    static let curvatureSwitchNames: Set<String> = [
        "curvature", "h_curvature", "crt_curvature", "curv", "warpx", "warpy", "warp_x", "warp_y",
        "curvature_x", "curvature_y", "geom_curvature", "crtcurvature"
    ]

    /// Values that switch off `entry`'s own curvature: the TV's glass is the only thing that
    /// bends the picture. Empty when the filter has no such switch.
    static func curvatureOffValues(for entry: ShaderCatalogEntry) -> [String: Float] {
        var values: [String: Float] = [:]
        for parameter in entry.parameters where !parameter.isHeading
            && curvatureSwitchNames.contains(parameter.name.lowercased())
            && parameter.minimum <= 0 && parameter.maximum >= 0 {
            values[parameter.name] = 0
        }
        return values
    }

    /// A built-in filter that bends the picture itself and cannot be told not to here: its
    /// settings are the player's saved ones. The TV's glass stays flat under it instead.
    static func bendsPictureItself(_ entry: ShaderCatalogEntry) -> Bool {
        guard entry.id.kind == .native else { return false }
        return entry.parameters.contains { parameter in
            let name = parameter.name.lowercased()
            return name.contains("curv") || name.contains("warp")
        }
    }

    /// A filter that draws a frame of its own, which cannot go inside a TV.
    static func isBezelFilter(_ entry: ShaderCatalogEntry) -> Bool {
        entry.looks.contains(.bezel)
    }
}

// MARK: - Pause menu

#if os(iOS) || os(tvOS)
import SkinKitBezelsUI

extension PauseMenuNavigationCommand {
    /// Inside the bezel views X is room light and Y is "this game only" (not quick save and
    /// load), and L1 and R1 jump between groups.
    var bezelCommand: BezelNavigationCommand {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .activate: return .activate
        case .back: return .back
        case .previousTab: return .previousGroup
        case .nextTab: return .nextGroup
        case .quickSave: return .toggleRoomLight
        case .quickLoad: return .toggleThisGameOnly
        }
    }
}

extension Publisher where Output == PauseMenuNavigationCommand, Failure == Never {
    /// The pause menu's controller input as the bezel views take it.
    var bezelCommands: AnyPublisher<BezelNavigationCommand, Never> {
        map(\.bezelCommand).eraseToAnyPublisher()
    }
}

/// The running game as the shared TV switcher sees it.
@MainActor
final class EmulatorBezelSession: BezelSwitcherSession {
    private let emulatorVC: PVEmulatorViewController

    init(_ emulatorVC: PVEmulatorViewController) {
        self.emulatorVC = emulatorVC
    }

    var bezelGameID: String? { emulatorVC.shaderGameMD5 }
    var bezelSystemID: String? { emulatorVC.shaderSystemID }
    var bezelSystemSuitsTV: Bool { emulatorVC.systemSuitsTV }
    var canShowBezel: Bool { emulatorVC.offersBezelSwitcher }
    var isBezelLoading: Bool { (emulatorVC.gpuViewController as? PVMetalViewController)?.isLocalBezelLoading ?? false }

    var bezelPreview: BezelPreview? {
        get { emulatorVC.bezelPreview }
        set { emulatorVC.bezelPreview = newValue }
    }
}
#endif
