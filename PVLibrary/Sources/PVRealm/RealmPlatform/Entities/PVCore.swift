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

public extension PVCore {
    /// Cores removed from the app, mapped to the core that now runs their games
    /// and save states.
    static let retiredCoreReplacements: [String: String] = [
        // Native PVJaguar ran the same virtualjaguar libretro.c as the dylib,
        // so its save states load there (the core reads older state versions).
        "com.provenance.core.jaguar": "virtualjaguar.libretro.framework"
    ]

    /// The retirements in effect in this build: those whose replacement is
    /// bundled. Lite builds ship no libretro dylibs and keep the old core.
    static let activeRetiredCoreReplacements: [String: String] =
        retiredCoreReplacements.filter { isBundledLibretroCore($0.value) }

    /// The identifier of the core that now handles `identifier`. Save states,
    /// recents and preferences are moved over at launch (`RetiredCoreMigration`);
    /// records arriving later from iCloud, another device or an exported save
    /// still name the old core, so lookups of an incoming identifier go through
    /// this.
    static func currentIdentifier(for identifier: String) -> String {
        activeRetiredCoreReplacements[identifier] ?? identifier
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
