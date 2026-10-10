//
//  PVCore.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import os
import PVLogging
import PVPrimitives
import PVSystems

@objcMembers
public final class PVCore: RealmSwift.Object, Identifiable {
    @Persisted(primaryKey: true) public var identifier: String = ""
    @Persisted public var principleClass: String = ""
    @Persisted public var supportedSystems: List<PVSystem>

    @Persisted public var projectName = ""
    @Persisted public var projectURL = ""
    @Persisted public var projectVersion = ""
    @Persisted public var disabled = false
    @Persisted public var appStoreDisabled = false
    @Persisted public var contentless = false

    /// Stored as display-name strings for Realm/ObjC compatibility.
    @Persisted public var supportedCheatTypeNames: List<String>

    /// Type-safe Swift accessor for the supported cheat code formats.
    public var supportedCheatTypes: [CheatCodeTypes] {
        supportedCheatTypeNames.compactMap { CheatCodeTypes(string: $0) }
    }

    /// SPDX license identifier (e.g. `"GPL-2.0-only"`, `"MIT"`). `nil` if not specified.
    @Persisted public var licenseName: String?
    /// URL pointing to the full license text. `nil` if not specified.
    @Persisted public var licenseURL: String?
    /// Copyright statement(s) for this core. `nil` if not specified.
    @Persisted public var copyright: String?

    public var hasCoreClass: Bool {
        if let _class: AnyClass = NSClassFromString(principleClass) {
            DLOG("Class: \(String(describing: _class)) for \(principleClass)")
            return true
        }
        // RetroArch-family principle classes (kept in Core.plist as registry keys) have no
        // class of their own: PVCoreFactory instantiates PVThinLibretroCore for them. Such a
        // core is available when its libretro dylib is bundled — Lite builds register the
        // whole RetroArch core list but ship no dylibs.
        if principleClass.contains("RetroArch") || principleClass.contains("LibRetro") || principleClass == "PVRetroArchCoreBridge" {
            let bundled = Self.isBundledLibretroCore(identifier)
            DLOG("Class: \(principleClass) not loaded — \(identifier) \(bundled ? "available via PVThinLibretroCore" : "has no bundled dylib")")
            return bundled
        }
        DLOG("Class: nil for \(principleClass)")
        return false
    }

    // Reverse links
    @Persisted(originProperty: "core") public var saveStates: LinkingObjects<PVSaveState>

    public convenience init(
        withIdentifier identifier: String,
        principleClass: String,
        supportedSystems: [PVSystem],
        name: String,
        url: String,
        version: String,
        disabled: Bool = false,
        appStoreDisabled: Bool = false,
        contentless: Bool = false,
        supportedCheatTypes: [CheatCodeTypes] = [],
        licenseName: String? = nil,
        licenseURL: String? = nil,
        copyright: String? = nil
    ) {
        self.init()
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems.removeAll()
        self.supportedSystems.append(objectsIn: supportedSystems)
        projectName = name
        projectURL = url
        projectVersion = version
        self.disabled = disabled
        self.appStoreDisabled = appStoreDisabled
        self.contentless = contentless
        self.supportedCheatTypeNames.removeAll()
        self.supportedCheatTypeNames.append(objectsIn: supportedCheatTypes.map { $0.stringValue })
        self.licenseName = licenseName
        self.licenseURL = licenseURL
        self.copyright = copyright
    }

    public override class func ignoredProperties() -> [String] {
        ["hasCoreClass", "id", "supportedCheatTypes"]
    }

    public var id: String {
        return identifier
    }
}

// MARK: - Retired cores

/// Identifiers of native cores removed from the app (their Core.plist `PVCoreIdentifier`).
/// Kept so records naming them can still be found and moved.
public enum RetiredCoreID {
    public static let jaguar = "com.provenance.core.jaguar"
}

/// Identifiers of the libretro cores that replace them (`PVCoreIdentifier` in
/// CoresRetro/RetroArch/Core.plist: the cores.yml name with dots, plus `.libretro.framework`).
public enum LibretroCoreID {
    public static let virtualJaguar = "virtualjaguar.libretro.framework"
}

/// Where a retired core kept a battery save, and how its replacement gets it.
/// The thin wrapper reads `Battery States/<rom>/<rom>.srm` (RETRO_MEMORY_SAVE_RAM).
public struct RetiredBatterySaveRule: Equatable, Sendable {
    public enum Location: Equatable, Sendable {
        /// `Battery States/<rom>/`: the core's `batterySavesPath`.
        case batterySaves
        /// `Save States/<rom>/`: the legacy libretro bridge answered GET_SAVE_DIRECTORY with it.
        case saveStates
    }

    public let location: Location
    /// Extension of `<rom>.<ext>`, the file the retired core wrote.
    public let fileExtension: String
    /// Move the file into `Battery States/<rom>/` (for `.saveStates`).
    public let moveToBatterySaves: Bool
    /// Copy it to `Battery States/<rom>/<rom>.srm` when that file doesn't exist yet.
    public let copyToSRM: Bool

    public init(location: Location, fileExtension: String, moveToBatterySaves: Bool = false, copyToSRM: Bool = false) {
        self.location = location
        self.fileExtension = fileExtension
        self.moveToBatterySaves = moveToBatterySaves
        self.copyToSRM = copyToSRM
    }

    /// A raw battery file in Battery States, copied to the thin wrapper's `.srm`.
    public static func copiedToSRM(_ fileExtension: String) -> RetiredBatterySaveRule {
        RetiredBatterySaveRule(location: .batterySaves, fileExtension: fileExtension, copyToSRM: true)
    }

    /// A file the legacy bridge left in Save States, moved to Battery States.
    public static func movedFromSaveStates(_ fileExtension: String, copyToSRM: Bool = false) -> RetiredBatterySaveRule {
        RetiredBatterySaveRule(location: .saveStates, fileExtension: fileExtension, moveToBatterySaves: true, copyToSRM: copyToSRM)
    }
}

/// A native core removed from the app and the libretro core(s) that now run its games.
public struct RetiredCore: Equatable, Sendable {
    public let replacement: String
    /// Systems whose games go to a different replacement than `replacement`.
    public let systemReplacements: [SystemIdentifier: String]
    /// Save states load in the replacement (same emulator code). When false they keep the
    /// retired core, whose disabled row is never pruned.
    public let migratesSaveStates: Bool
    public let batterySaves: [RetiredBatterySaveRule]

    public init(replacement: String, systemReplacements: [SystemIdentifier: String] = [:],
                migratesSaveStates: Bool = false, batterySaves: [RetiredBatterySaveRule] = []) {
        self.replacement = replacement
        self.systemReplacements = systemReplacements
        self.migratesSaveStates = migratesSaveStates
        self.batterySaves = batterySaves
    }

    public func replacement(forSystem systemIdentifier: String?) -> String {
        guard let system = systemIdentifier.flatMap(SystemIdentifier.init(rawValue:)),
              let override = systemReplacements[system] else { return replacement }
        return override
    }

    public var allReplacements: [String] { [replacement] + systemReplacements.values.sorted() }
}

public extension PVCore {
    /// Cores removed from the app. See RetiredCoreMigration and RetiredBatterySaveMigration.
    static let retiredCores: [String: RetiredCore] = [
        // Native PVJaguar ran the same virtualjaguar libretro.c as the dylib,
        // so its save states load there (the core reads older state versions).
        RetiredCoreID.jaguar: RetiredCore(replacement: LibretroCoreID.virtualJaguar, migratesSaveStates: true),
    ]

    /// Retired core → its default replacement.
    static var retiredCoreReplacements: [String: String] { retiredCores.mapValues(\.replacement) }

    /// The retirements in effect in this build: those whose replacements are all
    /// bundled. Lite builds ship no libretro dylibs and keep the old core.
    static let activeRetiredCores: [String: RetiredCore] =
        retiredCores.filter { $0.value.allReplacements.allSatisfy(isBundledLibretroCore) }

    static let activeRetiredCoreReplacements: [String: String] = activeRetiredCores.mapValues(\.replacement)

    /// The identifier of the core that now loads `identifier`'s save states. Records arriving
    /// from iCloud, another device or an export still name the old core, so save-state lookups
    /// go through this. Only retirements whose save states migrate are remapped.
    static func currentIdentifier(for identifier: String) -> String {
        currentIdentifier(for: identifier, in: activeRetiredCores)
    }

    static func currentIdentifier(for identifier: String, in cores: [String: RetiredCore]) -> String {
        guard let retired = cores[identifier], retired.migratesSaveStates else { return identifier }
        return retired.replacement
    }

    /// Whether the app bundle contains the libretro core `identifier`
    /// (`<name>.libretro.framework` in its Frameworks folder).
    static func isBundledLibretroCore(_ identifier: String) -> Bool {
        guard identifier.hasSuffix(".libretro.framework") else { return false }
        // The bundle doesn't change while the app runs, and `hasCoreClass` (which
        // calls this) runs inside core-picker filters.
        if let cached = bundledLibretroCoreCache.withLock({ $0[identifier] }) {
            return cached
        }
        let bases = [Bundle.main.privateFrameworksURL,
                     Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true)]
        let bundled = bases.compactMap { $0 }.contains {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent(identifier, isDirectory: true).path)
        }
        bundledLibretroCoreCache.withLock { $0[identifier] = bundled }
        return bundled
    }

    private static let bundledLibretroCoreCache = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])
}
