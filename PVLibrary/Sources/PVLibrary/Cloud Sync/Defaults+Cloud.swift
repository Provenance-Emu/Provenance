//
//  Defaults+Cloud.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Defaults

// MARK: - Default Extensions

public extension Defaults.Keys {
    /// Auto-sync new content
    static let autoSyncNewContent = Key<Bool>("autoSyncNewContent", default: true)
}
