//
//  DeltaSkinManagerProtocol.swift
//  PVUI
//
//  Created by Joseph Mattiello on 1/25/25.
//

/// Protocol for managing collections of skins
public protocol DeltaSkinManagerProtocol {
    /// Get all available skins
    func availableSkins() async throws -> [DeltaSkinProtocol]

    /// Load a skin from a file URL
    func loadSkin(from url: URL) async throws -> DeltaSkinProtocol

    /// Get skins for a specific game type
    func skins(for gameType: String) async throws -> [DeltaSkinProtocol]
}
