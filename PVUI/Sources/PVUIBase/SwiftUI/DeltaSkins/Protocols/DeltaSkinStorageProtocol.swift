//
//  DeltaSkinStorageProtocol.swift
//  PVUI
//
//  Created by Joseph Mattiello on 1/25/25.
//

/// Protocol for loading/saving skins
public protocol DeltaSkinStorageProtocol {
    /// Get the directory where skins are stored
    func skinsDirectory() throws -> URL

    /// Save a skin file to storage
    func saveSkin(_ data: Data, withIdentifier identifier: String) async throws -> URL

    /// Delete a skin from storage
    func deleteSkin(withIdentifier identifier: String) async throws

    /// Get URL for a skin identifier
    func url(forSkinIdentifier identifier: String) -> URL?
}
