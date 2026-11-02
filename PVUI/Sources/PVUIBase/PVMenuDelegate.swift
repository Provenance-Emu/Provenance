//
//  PVMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/23/24.
//

import UIKit
import SwiftUI

public protocol PVMenuDelegate: AnyObject {
    func didTapImports()
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
    func closeMenu()

    // MARK: - Library Management Actions

    /// Scan ROM directories for new and updated files. Does not modify existing metadata.
    func didTapScanROMs()

    /// Re-fetch metadata and artwork from the database. Preserves custom artwork and names.
    func didTapUpdateMetadata()

    /// Delete all cached artwork to free space. Images are re-downloaded on demand.
    func didTapClearArtworkCache()

    /// Delete all game data, settings and configurations, then re-import everything.
    /// This is destructive and removes custom artwork and names.
    func didTapResetLibrary()

    /// Open the in-app free ROM browser from a host that outlives the empty-library screen.
    func didTapFreeROMs()
}

// MARK: - Default Library Management Implementations

/// Default implementations post the existing NSNotification names so all existing
/// observers (PVAppDelegate) continue to work without any changes.
public extension PVMenuDelegate {

    func didTapScanROMs() {
        NotificationCenter.default.post(name: .PVReimportLibrary, object: nil)
    }

    func didTapUpdateMetadata() {
        NotificationCenter.default.post(name: .PVRefreshLibrary, object: nil)
    }

    func didTapClearArtworkCache() {
        // No notification needed — callers invoke PVMediaCache.empty() directly.
    }

    func didTapResetLibrary() {
        NotificationCenter.default.post(name: .PVResetLibrary, object: nil)
    }

    func didTapFreeROMs() {
        didTapImports()
    }
}
