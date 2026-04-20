//
//  PVCore.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
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
        #if os(tvOS)
        // tvOS ships without PVRetroArchCore; RetroArch-family principle classes
        // resolve to PVThinLibretroCore at instantiation time. Treat them as
        // available here so the core picker still surfaces them.
        if principleClass.contains("RetroArch") || principleClass.contains("LibRetro") || principleClass == "PVRetroArchCoreBridge" {
            DLOG("Class: \(principleClass) missing on tvOS — available via PVThinLibretroCore")
            return true
        }
        #endif
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
