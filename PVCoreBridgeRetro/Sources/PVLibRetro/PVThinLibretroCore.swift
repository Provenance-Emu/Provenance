//
//  PVThinLibretroCore.swift
//  PVCoreBridgeRetro
//
//  Created by Joe Mattiello on 2026-03-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Swift `PVEmulatorCore` subclass that wraps `PVThinLibretroFrontend`.
//  This class is the `principleClass` registered in dynamically-scanned
//  libretro core plists, giving `PVCoreFactory.createInstance(forSystem:)`
//  a proper `PVEmulatorCore` subclass to instantiate.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVLogging
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
#endif

/// Internal to keep `PVEmulatorCore` out of the generated
/// `PVCoreBridgeRetro-Swift.h` header (which would break every
/// downstream ObjC core target). `@objc` ensures the class is
/// registered with the ObjC runtime so `NSClassFromString` /
/// `principleClass` lookups still work.
// swiftlint:disable:next attributes
@objc(PVThinLibretroCore) @objcMembers
class PVThinLibretroCore: PVEmulatorCore {

    // MARK: Lifecycle

    /// Weak reference to the currently-active thin core instance.
    /// Used by the static `options` accessor since `CoreOptional` is static.
    /// Only one emulation runs at a time so this is safe.
    nonisolated(unsafe) static weak var current: PVThinLibretroCore?

    lazy var _bridge: PVThinLibretroFrontend = .init()

    // MARK: - RetroAchievements backing storage
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?
    var _hardcoreMode: Bool = false

    // MARK: - Skin support

    /// Systems that don't have adequate skin support — disable skins to show
    /// the native on-screen controls or core-specific overlays instead.
    private static let skinUnsupportedSystems: Set<String> = [
        "com.provenance.3ds",
        "com.provenance.ds",
        "com.provenance.dos",
        "com.provenance.mame",
        "com.provenance.arcade",
        "com.provenance.palmos",
        "com.provenance.cps1",
        "com.provenance.cps2",
        "com.provenance.cps3",
        "com.provenance.msx",
        "com.provenance.msx2"
    ]

    public override var supportsSkins: Bool {
        guard let sysId = systemIdentifier else { return true }
        return !Self.skinUnsupportedSystems.contains(sysId)
    }

    required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
        PVThinLibretroCore.current = self
    }

    public override func startEmulation() {
        // Wire system profile for better haptic tuning.
        if let sysId = systemIdentifier {
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.setSystemProfile(forSystemIdentifier: sysId)
            }
#endif
        }
        // Apply per-core iOS-specific option defaults before the emulation loop starts.
        // These match what PVRetroArchCore+Options.swift sets for the full RA bridge.
        applyPlatformDefaults()
        // Register a post-load hook so port device types are restored AFTER retro_load_game
        // (which triggers SET_CONTROLLER_INFO) but BEFORE the emulation loop thread starts,
        // avoiding a potential race condition with retro_set_controller_port_device.
        _bridge.afterROMLoadBlock = { [weak self] in
            self?.restorePortDeviceTypes()
        }
        super.startEmulation()
    }

    public override func stopEmulation() {
        // Reset haptic profile to generic so the next core doesn't inherit this system's tuning.
#if canImport(GameController) && canImport(CoreHaptics)
        if #available(iOS 14.0, tvOS 14.0, *) {
            GCControllerHapticsManager.shared.resetSystemProfile()
        }
#endif
        super.stopEmulation()
    }

    // MARK: - Per-core platform defaults

    /// Set iOS-specific core option defaults that differ from the core's
    /// built-in defaults. Only writes if the option hasn't been set yet
    /// (respects user overrides).
    private func applyPlatformDefaults() {
        let coreId = (coreIdentifier ?? "").lowercased()
        let sysId = (systemIdentifier ?? "").lowercased()

        // MelonDS: enable touch mode for DS
        if coreId.contains("melonds") {
            setDefaultOption("melonds_touch_mode", value: "Touch")
        }

        // DeSmuME: enable touch mode for DS
        if coreId.contains("desmume") {
            setDefaultOption("desmume_pointer_type", value: "touch")
        }

        // DOSBox Pure: use mouse pad mode + enable MIDI
        if coreId.contains("dosbox") {
            setDefaultOption("dosbox_pure_mouse_input", value: "pad")
            setDefaultOption("dosbox_pure_midi", value: "enabled")
        }

        // PPSSPP: interpreter + high res + texture scaling
        if coreId.contains("ppsspp") {
            setDefaultOption("ppsspp_cpu_core", value: "Interpreter")
            setDefaultOption("ppsspp_internal_resolution", value: "1920x1088")
            setDefaultOption("ppsspp_texture_scaling_level", value: "5x")
            setDefaultOption("ppsspp_ignore_bad_memory_access", value: "enabled")
            setDefaultOption("ppsspp_fast_memory", value: "enabled")
        }

        // Mupen64Plus-Next: use angrylion RDP
        if coreId.contains("mupen") {
            setDefaultOption("mupen64plus-rdp-plugin", value: "angrylion")
        }

        // PrBoom: enable rumble
        if coreId.contains("prboom") {
            setDefaultOption("prboom-rumble", value: "enabled")
        }

        // SNES: set mouse on port 2 for Mario Paint and similar games
        if sysId.contains("snes") {
            let romName = (_bridge.romPath as? NSString)?.lastPathComponent.lowercased() ?? ""
            if romName.contains("mario paint") || romName.contains("mariopaint") {
                _bridge.setControllerPortDevice(2, forPort: 1) // RETRO_DEVICE_MOUSE on port 2
                ILOG("ThinLibretroCore: set SNES port 2 to RETRO_DEVICE_MOUSE for Mario Paint")
            }
        }

        // Hatari: disable HD boot + copy hatari.cfg if needed
        if coreId.contains("hatari") || sysId.contains("atarist") {
            setDefaultOption("hatari_boot_hd", value: "disabled")
            copyBundledConfigIfNeeded(resourceName: "hatari", extension: "cfg",
                                      toDirectory: self.BIOSPath, fileName: "hatari.cfg")
        }

        // VecX: use software renderer — hardware mode requires a full GL context
        // that PVThinLibretroFrontend doesn't negotiate properly, causing the
        // "starting emulator..." HUD to hang indefinitely (video_refresh never fires).
        if coreId.contains("vecx") {
            setDefaultOption("vecx_use_hw", value: "Software")
        }

        // MAME: enable config read/write, boot to BIOS, cheats
        if coreId.contains("mame") {
            setDefaultOption("mame_read_config", value: "enabled")
            setDefaultOption("mame_write_config", value: "enabled")
            setDefaultOption("mame_boot_to_bios", value: "enabled")
            setDefaultOption("mame_cheats_enable", value: "enabled")
        }

        // Beetle PSX HW: use Vulkan
        if coreId.contains("psx_hw") || coreId.contains("beetle_psx") {
            setDefaultOption("beetle_psx_hw_renderer", value: "hardware_vk")
        }
    }

    /// Copy a bundled config file to the system/BIOS directory if it doesn't already exist.
    private func copyBundledConfigIfNeeded(resourceName: String, extension ext: String,
                                            toDirectory dir: String?, fileName: String) {
        guard let dir = dir else { return }
        let destPath = (dir as NSString).appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: destPath) else { return }

        // Look in the main bundle and all framework bundles
        let bundles = [Bundle.main] + Bundle.allFrameworks
        for bundle in bundles {
            if let srcURL = bundle.url(forResource: resourceName, withExtension: ext) {
                do {
                    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: srcURL, to: URL(fileURLWithPath: destPath))
                    ILOG("ThinLibretroCore: copied \(fileName) to \(dir)")
                    return
                } catch {
                    WLOG("ThinLibretroCore: failed to copy \(fileName): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Set a core option only if it hasn't been set yet (preserves user overrides).
    private func setDefaultOption(_ key: String, value: String) {
        let current = _bridge.coreOptions[key] as? String
        if current == nil {
            _bridge.setCoreOption(key, value: value)
        }
    }
}

// MARK: - CoreOptional

extension PVThinLibretroCore: @preconcurrency CoreOptional {

    static var options: [CoreOption] {
        guard let instance = PVThinLibretroCore.current else {
            return []
        }
        return instance.buildOptions()
    }

    /// Build CoreOption models from the bridge's structured option metadata.
    /// Called by the options UI each time the screen appears, so it reflects
    /// the latest state (including visibility changes).
    func buildOptions() -> [CoreOption] {
        let definitions = _bridge.coreOptionDefinitions
        let categories = _bridge.coreOptionCategories
        let visibility = _bridge.coreOptionVisibility
        let currentValues = _bridge.coreOptions

        // Filter out hidden options
        let visibleDefs = definitions.filter { dict in
            guard let key = dict["key"] as? String else { return false }
            if let vis = visibility[key] {
                return vis.boolValue
            }
            return true // visible by default
        }

        // Build a category key -> [CoreOption] map
        var categorizedOptions: [String: [CoreOption]] = [:]
        var uncategorizedOptions: [CoreOption] = []

        for dict in visibleDefs {
            guard let option = coreOptionFromDictionary(dict, currentValues: currentValues) else {
                continue
            }
            if let categoryKey = dict["category"] as? String {
                categorizedOptions[categoryKey, default: []].append(option)
            } else {
                uncategorizedOptions.append(option)
            }
        }

        // Build category groups
        var result: [CoreOption] = []
        for catDict in categories {
            guard let catKey = catDict["key"] as? String,
                  let subOptions = categorizedOptions[catKey],
                  !subOptions.isEmpty else {
                continue
            }
            let catDesc = (catDict["desc"] as? String) ?? catKey
            let catInfo = catDict["info"] as? String
            let display = CoreOptionValueDisplay(
                title: catDesc,
                description: catInfo,
                requiresRestart: false
            )
            result.append(.group(display, subOptions: subOptions))
        }

        // Append uncategorized options at the top level
        result.append(contentsOf: uncategorizedOptions)

        DLOG("ThinLibretroCore: built \(result.count) top-level options (\(visibleDefs.count) visible of \(definitions.count) total)")
        return result
    }

    /// Convert a single NSDictionary option definition to a CoreOption.
    private func coreOptionFromDictionary(
        _ dict: [String: Any],
        currentValues: [String: String]
    ) -> CoreOption? {
        guard let key = dict["key"] as? String,
              let desc = dict["desc"] as? String else {
            return nil
        }
        let info = dict["info"] as? String
        let defaultValue = dict["default"] as? String ?? ""
        let valuesArray = dict["values"] as? [[String: String]] ?? []

        // desc = human-readable label (e.g. "Video Resolution")
        // info = longer help text (e.g. "Set the internal rendering resolution")
        // key = machine identifier (e.g. "flycast_video_resolution")
        let displayTitle = desc
        let descriptionText = info

        // Detect boolean options (exactly two values: enabled/disabled or on/off etc.)
        if valuesArray.count == 2 {
            let v0 = valuesArray[0]["value"]?.lowercased() ?? ""
            let v1 = valuesArray[1]["value"]?.lowercased() ?? ""
            let boolPairs: Set<Set<String>> = [
                ["enabled", "disabled"],
                ["on", "off"],
                ["true", "false"],
                ["yes", "no"],
                ["1", "0"]
            ]
            if boolPairs.contains(Set([v0, v1])) {
                let enabledValues: Set<String> = ["enabled", "on", "true", "yes", "1"]
                let defaultBool = enabledValues.contains(defaultValue.lowercased())
                let display = CoreOptionValueDisplay(
                    title: displayTitle,
                    description: descriptionText,
                    requiresRestart: false
                )
                let enabledStr = valuesArray[0]["value"] ?? "enabled"
                let disabledStr = valuesArray[1]["value"] ?? "disabled"
                let bridgeRef = _bridge
                return .bool(display, defaultValue: defaultBool) { @Sendable newValue in
                    let boolVal = (newValue as? Bool) ?? false
                    let stringVal = boolVal ? enabledStr : disabledStr
                    bridgeRef.setCoreOption(key, value: stringVal)
                }
            }
        }

        // Multi-value option (most common for libretro)
        let multiValues: [CoreOptionMultiValue] = valuesArray.map { entry in
            let val = entry["value"] ?? ""
            let label = entry["label"] ?? val
            let isDefault = (val == defaultValue)
            // Show human label as title, raw value as description (for debugging)
            return CoreOptionMultiValue(title: label, description: val, isDefault: isDefault)
        }

        let display = CoreOptionValueDisplay(
            title: key,
            description: descriptionText,
            requiresRestart: false
        )

        let bridgeRef = _bridge
        return .multi(display, values: multiValues) { @Sendable newValue in
            if let strVal = newValue as? String {
                bridgeRef.setCoreOption(key, value: strVal)
            } else if let intVal = newValue as? Int, intVal < valuesArray.count {
                let strVal = valuesArray[intVal]["value"] ?? ""
                bridgeRef.setCoreOption(key, value: strVal)
            }
        }
    }
}

// MARK: - PortDeviceConfigurable

extension PVThinLibretroCore: PortDeviceConfigurable {

    /// Authoritative per-platform max from the ObjC frontend.
    /// Avoids duplicating the THIN_MAX_PLAYERS preprocessor constant in Swift.
    private var thinMaxPlayers: Int { Int(PVThinLibretroFrontend.maxPlayers) }

    public var controllerPortDescriptors: [[PortDeviceDescriptor]] {
        // Clamp to thinMaxPlayers — ports beyond this cannot be tracked or restored.
        let portInfo = _bridge.controllerPortInfo.prefix(thinMaxPlayers)
        return portInfo.map { portTypes in
            portTypes.compactMap { dict -> PortDeviceDescriptor? in
                guard let name = dict["desc"] as? String,
                      let typeNum = dict["id"] as? NSNumber else { return nil }
                return PortDeviceDescriptor(name: name, deviceType: typeNum.uintValue)
            }
        }
    }

    public func currentDeviceType(forPort port: Int) -> UInt {
        guard port >= 0, port < thinMaxPlayers else { return LibretroDeviceType.joypad.rawValue }
        return UInt(_bridge.currentDeviceType(forPort: UInt32(port)))
    }

    public func setDeviceType(_ deviceType: UInt, forPort port: Int) {
        guard port >= 0, port < thinMaxPlayers else { return }
        _bridge.setControllerPortDevice(UInt32(deviceType), forPort: UInt32(port))
        // Persist selection per core + game combo
        let key = portDevicePersistenceKey(port: port)
        UserDefaults.standard.set(Int(deviceType), forKey: key)
    }

    /// Restore saved device type selections (called after core loads).
    func restorePortDeviceTypes() {
        // Clamp to thinMaxPlayers — _portDeviceTypes[] only has 4 entries.
        let portCount = min(_bridge.controllerPortInfo.count, thinMaxPlayers)
        for port in 0..<portCount {
            let key = portDevicePersistenceKey(port: port)
            if UserDefaults.standard.object(forKey: key) != nil {
                let saved = UInt(UserDefaults.standard.integer(forKey: key))
                _bridge.setControllerPortDevice(UInt32(saved), forPort: UInt32(port))
            } else {
                // Migration path: fall back to legacy per-game key (no core identifier)
                let legacyKey = legacyPortDevicePersistenceKey(port: port)
                if UserDefaults.standard.object(forKey: legacyKey) != nil {
                    let saved = UInt(UserDefaults.standard.integer(forKey: legacyKey))
                    _bridge.setControllerPortDevice(UInt32(saved), forPort: UInt32(port))
                    // Re-save under the new per-core/per-game key so future lookups hit the new namespace.
                    UserDefaults.standard.set(Int(saved), forKey: key)
                }
            }
        }
    }

    /// New-style per-port key: <ClassName>.<md5>.<coreIdentifier>.portDeviceType.port<port>
    private func portDevicePersistenceKey(port: Int) -> String {
        // Key format matches CoreOptions+Serialization convention: <ClassName>.<md5>.<key>
        let md5 = PVThinLibretroCore.currentGameMD5 ?? "global"
        // Prefer the coreIdentifier from PVEmulatorCore if available; fall back to the dynamic type name.
        let coreIdentifierComponent: String
        if let identifier = (self as PVEmulatorCore).coreIdentifier, !identifier.isEmpty {
            coreIdentifierComponent = identifier
        } else {
            coreIdentifierComponent = String(describing: type(of: self))
        }
        return "PVThinLibretroCore.\(md5).\(coreIdentifierComponent).portDeviceType.port\(port)"
    }

    /// Legacy per-port key used before core identifiers were included (per-game only).
    /// Format: <ClassName>.<md5>.portDeviceType.port<port>
    private func legacyPortDevicePersistenceKey(port: Int) -> String {
        let md5 = PVThinLibretroCore.currentGameMD5 ?? "global"
        return "PVThinLibretroCore.\(md5).portDeviceType.port\(port)"
    }
}
