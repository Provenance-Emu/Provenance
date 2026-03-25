//
//  ControllerLightBarManager.swift
//  PVCoreBridge
//
//  Manages controller light bar colors for DualSense and DualShock 4 controllers.
//  Applies per-system colors when a new emulation session starts.
//
//  Supports:
//  - DualSense: GCController.light API (iOS 14.0+)
//  - DualShock 4: GCController.light API (iOS 14.0+)
//  - Per-system default color map
//  - User-configurable overrides stored in UserDefaults
//

import Foundation
#if canImport(GameController)
import GameController
import PVLogging
import PVPrimitives

/// Manages light bar color output for DualSense and DualShock 4 controllers.
/// One shared instance applies per-system colors to all registered controllers.
@MainActor
@available(iOS 14.0, tvOS 14.0, *)
public final class ControllerLightBarManager {

    // MARK: - Singleton

    public static let shared = ControllerLightBarManager()

    // MARK: - Types

    /// An RGB color for the controller light bar. Each component is in [0, 1].
    public struct LightBarColor: Codable, Equatable {
        public var red: Float
        public var green: Float
        public var blue: Float

        public init(red: Float, green: Float, blue: Float) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Create from a CSS-style hex string (#RRGGBB or RRGGBB).
        public init?(hex: String) {
            let stripped = hex.trimmingCharacters(in: .init(charactersIn: "#"))
            guard stripped.count == 6,
                  let value = UInt32(stripped, radix: 16) else { return nil }
            red   = Float((value >> 16) & 0xFF) / 255.0
            green = Float((value >>  8) & 0xFF) / 255.0
            blue  = Float((value      ) & 0xFF) / 255.0
        }

        /// Hex string representation (#RRGGBB).
        public var hexString: String {
            let r = Int((red   * 255).rounded())
            let g = Int((green * 255).rounded())
            let b = Int((blue  * 255).rounded())
            return String(format: "#%02X%02X%02X", r, g, b)
        }

        // MARK: Predefined palette

        /// PlayStation blue — PS1/PS2/PS3 family.
        public static let playstationBlue   = LightBarColor(red: 0.00, green: 0.40, blue: 1.00)
        /// Nintendo SNES purple.
        public static let snesPurple        = LightBarColor(red: 0.51, green: 0.00, blue: 0.78)
        /// Game Boy green.
        public static let gameBoyGreen      = LightBarColor(red: 0.00, green: 0.60, blue: 0.20)
        /// NES grey/silver.
        public static let nesGray           = LightBarColor(red: 0.70, green: 0.70, blue: 0.70)
        /// N64 grey-blue.
        public static let n64Blue           = LightBarColor(red: 0.00, green: 0.30, blue: 0.70)
        /// Sega Mega Drive / Genesis blue.
        public static let segaBlue          = LightBarColor(red: 0.00, green: 0.45, blue: 0.80)
        /// Sega Dreamcast orange.
        public static let dreamcastOrange   = LightBarColor(red: 1.00, green: 0.45, blue: 0.00)
        /// Game Boy Advance purple.
        public static let gbaPurple         = LightBarColor(red: 0.40, green: 0.00, blue: 0.70)
        /// Nintendo GameCube indigo.
        public static let gameCubeIndigo    = LightBarColor(red: 0.25, green: 0.10, blue: 0.80)
        /// Xbox green.
        public static let xboxGreen         = LightBarColor(red: 0.10, green: 0.80, blue: 0.10)
        /// Atari gold.
        public static let atariGold         = LightBarColor(red: 1.00, green: 0.75, blue: 0.00)
        /// Default warm white when no system match.
        public static let `default`         = LightBarColor(red: 1.00, green: 1.00, blue: 1.00)
        /// Off — black, zero emission.
        public static let off               = LightBarColor(red: 0.00, green: 0.00, blue: 0.00)
    }

    // MARK: - Private State

    /// Maps 0-based player index → GCController.
    private var playerControllers: [Int: GCController] = [:]

    /// The system identifier of the currently active emulation session.
    private var currentSystemIdentifier: String?

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    private init() {
        registerNotifications()
    }

    private func registerNotifications() {
        let nc = NotificationCenter.default

        let connectObs = nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let gc = note.object as? GCController else { return }
            nonisolated(unsafe) let controller = gc
            MainActor.assumeIsolated { self?.controllerConnected(controller) }
        }
        notificationObservers.append(connectObs)

        let udObs = nc.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reapplyCurrentSystemColor() }
        }
        notificationObservers.append(udObs)
    }

    // MARK: - Player Registration

    /// Register a GCController for a player slot (0-based).
    public func register(controller: GCController?, forPlayer player: Int) {
        if let controller = controller {
            playerControllers[player] = controller
            if let sysId = currentSystemIdentifier {
                applyColor(forSystemIdentifier: sysId, to: controller)
            }
        } else {
            playerControllers.removeValue(forKey: player)
        }
    }

    // MARK: - System Color API

    /// Apply the appropriate light bar color for `sysId` to all registered controllers.
    /// Call this when a new emulation session starts (mirrors `GCControllerHapticsManager.setSystemProfile`).
    public func setSystemColor(forSystemIdentifier sysId: String) {
        currentSystemIdentifier = sysId
        reapplyCurrentSystemColor()
    }

    /// Reset the light bar to the default color and clear the current system.
    /// Call this when an emulation session ends.
    public func resetSystemColor() {
        currentSystemIdentifier = nil
        for controller in playerControllers.values {
            setLightBar(of: controller, to: .default)
        }
    }

    // MARK: - Private Helpers

    private func reapplyCurrentSystemColor() {
        guard let sysId = currentSystemIdentifier else { return }
        for controller in playerControllers.values {
            applyColor(forSystemIdentifier: sysId, to: controller)
        }
    }

    private func applyColor(forSystemIdentifier sysId: String, to controller: GCController) {
        guard isLightBarEnabled() else {
            setLightBar(of: controller, to: .off)
            return
        }
        let color = effectiveColor(forSystemIdentifier: sysId)
        setLightBar(of: controller, to: color)
    }

    private func setLightBar(of controller: GCController, to color: LightBarColor) {
        if #available(iOS 14.0, tvOS 14.0, *) {
            controller.light?.color = GCColor(red: color.red, green: color.green, blue: color.blue)
        }
    }

    private func controllerConnected(_ controller: GCController) {
        // If a system is active, apply its color immediately on connect.
        guard let sysId = currentSystemIdentifier else { return }
        applyColor(forSystemIdentifier: sysId, to: controller)
    }

    // MARK: - Color Resolution

    /// Resolve the effective color for a system identifier.
    /// Priority: user override → built-in default.
    public func effectiveColor(forSystemIdentifier sysId: String) -> LightBarColor {
        // User override: stored as hex string keyed by system identifier.
        if let overrides = UserDefaults.standard.dictionary(forKey: "controllerLightBarSystemColors") as? [String: String],
           let hexValue = overrides[sysId],
           let color = LightBarColor(hex: hexValue) {
            return color
        }
        return defaultColor(forSystemIdentifier: sysId)
    }

    private func isLightBarEnabled() -> Bool {
        UserDefaults.standard.object(forKey: "controllerLightBarEnabled") as? Bool ?? true
    }

    // MARK: - Default System Color Map

    /// Built-in default light bar color for a Provenance system identifier.
    public func defaultColor(forSystemIdentifier sysId: String) -> LightBarColor {
        let id = sysId.lowercased()

        // PlayStation family — blue shades
        if id.contains("psx") || id.contains("ps1") { return .playstationBlue }
        if id.contains("ps2") { return LightBarColor(red: 0.00, green: 0.30, blue: 0.90) }
        if id.contains("ps3") { return LightBarColor(red: 0.00, green: 0.20, blue: 0.80) }

        // Nintendo SNES — purple
        if id.contains("snes") || id.contains("superfamicom") { return .snesPurple }

        // NES / Famicom — grey
        if id.contains(".nes") || id.contains("famicom") { return .nesGray }

        // Game Boy family
        if id.contains("gba") { return .gbaPurple }
        if id.contains("gbc") { return LightBarColor(red: 0.20, green: 0.70, blue: 0.20) }
        if id.contains(".gb") { return .gameBoyGreen }

        // N64 — blue
        if id.contains("n64") { return .n64Blue }

        // GameCube — indigo
        if id.contains("gamecube") || id.contains("gcn") { return .gameCubeIndigo }

        // Sega
        if id.contains("genesis") || id.contains("megadrive") || id.contains("mastersystem") { return .segaBlue }
        if id.contains("dreamcast") { return .dreamcastOrange }
        if id.contains("gamegear") { return LightBarColor(red: 0.00, green: 0.65, blue: 0.90) }
        if id.contains("saturn") { return LightBarColor(red: 0.60, green: 0.60, blue: 0.00) }

        // Atari
        if id.contains("atari") { return .atariGold }

        // Default warm white
        return .default
    }
}

#endif // canImport(GameController)
