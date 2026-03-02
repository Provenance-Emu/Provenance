//
//  PVControllerMapping.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 2/28/2026.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

/// Persisted button mapping: maps one physical button to another button's action.
/// Stored as raw string values matching `ButtonIdentifier` cases.
@objcMembers
public final class PVControllerMapping: RealmSwift.EmbeddedObject {
    /// Raw value of the source `ButtonIdentifier`
    @Persisted public var sourceButton: String = ""
    /// Raw value of the destination `ButtonIdentifier`
    @Persisted public var destinationButton: String = ""

    public convenience init(source: String, destination: String) {
        self.init()
        self.sourceButton = source
        self.destinationButton = destination
    }
}
