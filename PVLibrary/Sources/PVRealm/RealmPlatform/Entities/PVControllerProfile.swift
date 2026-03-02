//
//  PVControllerProfile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 2/28/2026.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

/// A named set of custom button mappings for a particular controller type.
///
/// Profiles are scoped by `controllerVendorName` (the value of `GCController.vendorName`)
/// and can optionally be narrowed to a specific system, core, or game by storing
/// the system identifier, core identifier, or game MD5.  A `nil` scope means the profile is
/// a global default for that controller type.
///
/// Profile resolution priority (highest to lowest):
///   1. Game + Core-specific (`gameID` and `coreIdentifier` are set)
///   2. Game-specific  (`gameID` is set, `coreIdentifier` is nil)
///   3. System + Core-specific (`systemIdentifier` and `coreIdentifier` are set, `gameID` is nil)
///   4. System-specific (`systemIdentifier` is set, `coreIdentifier` and `gameID` are nil)
///   5. Controller default (all scope fields are nil)
@objcMembers
public final class PVControllerProfile: RealmSwift.Object, Identifiable {
    // MARK: - Primary key

    @Persisted(wrappedValue: UUID().uuidString, primaryKey: true) public var id: String

    // MARK: - Identity

    /// Human-readable profile name (e.g. "My DualSense Layout")
    @Persisted public var name: String = ""

    /// The `GCController.vendorName` this profile was created for (e.g. "DualSense Wireless Controller")
    @Persisted(indexed: true) public var controllerVendorName: String = ""

    // MARK: - Scope

    /// System identifier this profile applies to (nil = all systems)
    @Persisted public var systemIdentifier: String?

    /// Core identifier this profile applies to (nil = all cores for the given system/game)
    @Persisted public var coreIdentifier: String?

    /// MD5 hash of the game this profile applies to (nil = all games in scope)
    @Persisted public var gameID: String?

    // MARK: - Mappings

    /// The individual button remappings stored in this profile
    @Persisted public var mappings: List<PVControllerMapping>

    // MARK: - Metadata

    @Persisted public var createdDate: Date = Date()
    @Persisted public var lastModifiedDate: Date = Date()

    /// Whether this is the active profile for the given (controller, system, game) combination
    @Persisted public var isActive: Bool = false

    // MARK: - Init

    public convenience init(
        name: String,
        controllerVendorName: String,
        systemIdentifier: String? = nil,
        coreIdentifier: String? = nil,
        gameID: String? = nil
    ) {
        self.init()
        self.name = name
        self.controllerVendorName = controllerVendorName
        self.systemIdentifier = systemIdentifier
        self.coreIdentifier = coreIdentifier
        self.gameID = gameID
    }
}
