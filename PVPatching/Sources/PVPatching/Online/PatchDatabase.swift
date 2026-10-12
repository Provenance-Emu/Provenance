//
//  PatchDatabase.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Abstract online patch catalog (RomHacking.net and future sources).
public protocol PatchDatabase: Sendable {
    /// Human-readable source name.
    var displayName: String { get }

    /// Search the catalog.
    func search(
        query: String,
        filter: OnlinePatchSearchFilter
    ) async throws -> [OnlinePatchSearchResult]

    /// Fetch full metadata for a listing id (or page URL string id).
    func fetchPatchInfo(id: String) async throws -> OnlinePatchInfo

    /// Download the patch file to a local URL.
    func downloadPatch(
        id: String,
        to directory: URL,
        progress: (@Sendable (OnlinePatchDownloadProgress) -> Void)?
    ) async throws -> URL
}

public extension PatchDatabase {
    func search(query: String) async throws -> [OnlinePatchSearchResult] {
        try await search(query: query, filter: .empty)
    }

    func downloadPatch(id: String, to directory: URL) async throws -> URL {
        try await downloadPatch(id: id, to: directory, progress: nil)
    }
}
