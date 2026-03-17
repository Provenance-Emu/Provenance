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

    required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
        PVThinLibretroCore.current = self
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
