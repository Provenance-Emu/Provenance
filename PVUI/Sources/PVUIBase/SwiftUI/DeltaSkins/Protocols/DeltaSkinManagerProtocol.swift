//
//  DeltaSkinManagerProtocol.swift
//  PVUI
//
//  Created by Joseph Mattiello on 1/25/25.
//

/// Protocol for managing collections of skins
public protocol DeltaSkinManagerProtocol: ObservableObject {
    var loadedSkins: [any DeltaSkinProtocol] { get }

    /// Get all available skins
    func availableSkins() async throws -> [any DeltaSkinProtocol]

    /// Load a skin from a file URL
    func loadSkin(from url: URL) async throws -> any DeltaSkinProtocol

    /// Import a skin from a URL, handling spaces in paths
    func importSkin(from url: URL) async throws

    /// Check if a skin can be deleted
    func isDeletable(_ skin: any DeltaSkinProtocol) -> Bool

    /// Delete a skin by its identifier
    func deleteSkin(_ identifier: String) async throws

    /// Reload the list of skins in all available locations
    func reloadSkins() async
}
