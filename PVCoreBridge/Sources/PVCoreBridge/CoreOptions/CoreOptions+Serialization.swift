//
//  CoreOptions+Serialization.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

public extension CoreOptional { // where Self:PVEmulatorCore {
    static func storedValueForOption<T>(_: T.Type, _ option: String, andMD5 md5: String? = nil) -> T? {
        let className: String = "\(String(describing: Self.self))"
        let key =  "\(className).\(option)"
        let md5Key: String = [className, md5, option].compactMap {$0}.joined(separator: ".")
//        VLOG("Looking for either key's `\(key)` or \(md5Key) with type \(T.self)")

        let savedOption = UserDefaults.standard.object(forKey: md5Key) ??  UserDefaults.standard.object(forKey: key)
//        VLOG("savedOption found?: \(String(describing: savedOption)) isIt type: \(T.self), \(savedOption as? T)")

        if let savedOption = savedOption as? T {
//            VLOG("Read key `\(md5Key)` option: \(savedOption)")
            return savedOption
        } else {
//            VLOG("need to find options for key `\(option)`")
            let currentOptions: [CoreOption] = options
            guard let foundOption = findOption(forKey: option, options: currentOptions) else {
                print("Error: No option for key: `\(option)`")
                return nil
            }
//            VLOG("Found option `\(foundOption)`")
			let key = "\(className).\(foundOption.key)"
			let object = UserDefaults.standard.object(forKey: key)
			return object as? T ?? foundOption.defaultValue as? T
        }
    }

    static func setValue(_ value: Encodable?, forOption option: CoreOption, andMD5 md5: String? = nil) {
        let className: String = "\(String(describing: Self.self))"
        let key: String
        if let md5 = md5, !md5.isEmpty {
            key = "\(className).\(md5).\(option.key)"
        } else {
            key = "\(className).\(option.key)"
        }

        // TODO: Make sure the value matches the option type
        DLOG("Options: Setting key: \(key) to value: \(value ?? "nil")")
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()

        // Call the value handler if available
        if let valueHandler = option.valueHandler, let value = value as? OptionValueRepresentable {
            valueHandler(value)
        }

        let broadcast = NotificationCenter.default
        let info:Dictionary=[option.key: "\(value ?? "nil")"]
        broadcast.post(name: Notification.Name("OptionUpdated"), object: nil, userInfo:info)
    }

    // MARK: - Typed valueForOption overloads

    /// Read a Bool option, optionally scoped to a specific game's MD5.
    /// When `md5` is nil the method falls back to `currentGameMD5`, then
    /// to the per-core global key.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> Bool {
        return valueForOption(option, andMD5: md5).asBool
    }

    /// Read a String option, optionally scoped to a specific game's MD5.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> String {
        return valueForOption(option, andMD5: md5).asString
    }

    /// Read an optional Int option, optionally scoped to a specific game's MD5.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> Int? {
        return valueForOption(option, andMD5: md5).asInt ?? option.defaultValue as? Int
    }

    /// Read an optional Float option, optionally scoped to a specific game's MD5.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> Float? {
        return valueForOption(option, andMD5: md5).asFloat ?? option.defaultValue as? Float
    }

    /// Read a non-optional Int option, optionally scoped to a specific game's MD5.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> Int {
        return valueForOption(option, andMD5: md5).asInt ?? option.defaultValue as! Int
    }

    /// Read a non-optional UInt option, optionally scoped to a specific game's MD5.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> UInt {
        return valueForOption(option, andMD5: md5).asUInt ?? option.defaultValue as! UInt
    }

    /// Read a non-optional Float option, optionally scoped to a specific game's MD5.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> Float {
        return valueForOption(option, andMD5: md5).asFloat ?? option.defaultValue as! Float
    }

    /// Core read implementation. Resolves the effective MD5 using:
    ///   1. The explicitly supplied `md5` argument, or
    ///   2. `currentGameMD5` set on the conforming type.
    /// Per-game keys (`<ClassName>.<md5>.<optionKey>`) take precedence over
    /// per-core global keys (`<ClassName>.<optionKey>`). When no MD5 is
    /// available the result is equivalent to the global key.
    static func valueForOption(_ option: CoreOption, andMD5 md5: String? = nil) -> CoreOptionValue {
        let effectiveMD5 = md5 ?? currentGameMD5
        switch option {
        case let .bool(_, defaultValue, _):
            guard let value = storedValueForOption(Bool.self, option.key, andMD5: effectiveMD5) else { return .bool(defaultValue) }
            return .bool(value)
        case .string:
            if let value = storedValueForOption(String.self, option.key, andMD5: effectiveMD5) {
                return .string(value)
            } else {
                return .notFound
            }
        case let .range(_, _, defaultValue, _):
            if let value = storedValueForOption(Int.self, option.key, andMD5: effectiveMD5) {
                return .int(value)
            } else {
                return .int(defaultValue)
            }
        case let .rangef(_, _, defaultValue, _):
            if let value = storedValueForOption(Float.self, option.key, andMD5: effectiveMD5) {
                return .float(value)
            } else {
                return .float(defaultValue)
            }
        case .multi:
            if let value = storedValueForOption(Int.self, option.key, andMD5: effectiveMD5) {
                return .int(value)
            } else if let value = storedValueForOption(String.self, option.key, andMD5: effectiveMD5) {
                return .string(value)
            } else {
                return .notFound
            }
        case let .enumeration(_, _, defaultValue, _):
            if let value = storedValueForOption(Int.self, option.key, andMD5: effectiveMD5) {
                return .int(value)
            } else if let value = storedValueForOption(String.self, option.key, andMD5: effectiveMD5) {
                return .string(value)
            } else {
                return .int(defaultValue)
            }
        case .group:
            assertionFailure("Feature unfinished")
            return .notFound
        }
    }

    static func findOption(forKey key: String, options: [CoreOption]) -> CoreOption? {
        var foundOption: CoreOption?
        for option in options {
            let subOption = option.subOptionForKey(key)
            if subOption != nil {
                foundOption = subOption
            }
        }
        return foundOption
    }

    // MARK: - Per-game key helpers

    /// Builds the UserDefaults key for a per-game override: `<ClassName>.<md5>.<optionKey>`
    static func perGameKey(for option: CoreOption, md5: String) -> String {
        let className = "\(String(describing: Self.self))"
        return "\(className).\(md5).\(option.key)"
    }

    /// Builds the UserDefaults key prefix for all per-game overrides of a game: `<ClassName>.<md5>.`
    static func perGameKeyPrefix(md5: String) -> String {
        let className = "\(String(describing: Self.self))"
        return "\(className).\(md5)."
    }

    // MARK: - Per-game override inspection

    /// Returns `true` if a per-game override exists in UserDefaults for the given option and game MD5.
    ///
    /// Use this to show an "overridden" badge next to the option in the UI.
    static func hasPerGameOverride(for option: CoreOption, md5: String) -> Bool {
        let key = perGameKey(for: option, md5: md5)
        return UserDefaults.standard.object(forKey: key) != nil
    }

    // MARK: - Scoped reset

    /// Deletes the per-game UserDefaults entry for a single option, reverting it to the
    /// core-global value for the next read.
    ///
    /// Only removes `<ClassName>.<md5>.<optionKey>` — the core-global key is untouched.
    static func resetOption(_ option: CoreOption, forMD5 md5: String) {
        let key = perGameKey(for: option, md5: md5)
        DLOG("CoreOptions: removing per-game override key: \(key)")
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
    }

    /// Deletes **all** per-game UserDefaults entries for the given game MD5, reverting every
    /// option to its core-global value.
    ///
    /// Only removes keys matching the prefix `<ClassName>.<md5>.` — core-global keys and
    /// other games' per-game keys are untouched.
    static func resetAllOptions(forMD5 md5: String) {
        let prefix = perGameKeyPrefix(md5: md5)
        let defaults = UserDefaults.standard
        let keysToRemove = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        DLOG("CoreOptions: removing \(keysToRemove.count) per-game override(s) for md5 \(md5)")
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()
    }
}
