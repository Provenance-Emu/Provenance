//
//  PatchMetadata.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// User-visible metadata about a ROM patch.
public struct PatchMetadata: Sendable, Codable, Equatable {
    /// Patch title (e.g. "Super Mario Bros. — English Translation").
    public var title: String?
    /// Patch author or team.
    public var author: String?
    /// Patch version string (e.g. "v1.2").
    public var version: String?
    /// Human-readable description of what the patch does.
    public var description: String?
    /// Target ROM name as specified by the patch creator.
    public var targetROMName: String?
    /// CRC32 of the target (unpatched) ROM, if known.
    public var targetROMCRC32: UInt32?
    /// MD5 of the target (unpatched) ROM, if known.
    public var targetROMMD5: String?
    /// SHA1 of the target (unpatched) ROM, if known.
    public var targetROMSHA1: String?
    /// CRC32 expected after patching, if known.
    public var patchedROMCRC32: UInt32?
    /// Online source URL (e.g. RomHacking.net page).
    public var sourceURL: URL?
    /// Date the patch was created or released.
    public var releaseDate: Date?
    /// Category tags (e.g. "translation", "bugfix", "hack").
    public var categories: [String]

    public init(
        title: String? = nil,
        author: String? = nil,
        version: String? = nil,
        description: String? = nil,
        targetROMName: String? = nil,
        targetROMCRC32: UInt32? = nil,
        targetROMMD5: String? = nil,
        targetROMSHA1: String? = nil,
        patchedROMCRC32: UInt32? = nil,
        sourceURL: URL? = nil,
        releaseDate: Date? = nil,
        categories: [String] = []
    ) {
        self.title = title
        self.author = author
        self.version = version
        self.description = description
        self.targetROMName = targetROMName
        self.targetROMCRC32 = targetROMCRC32
        self.targetROMMD5 = targetROMMD5
        self.targetROMSHA1 = targetROMSHA1
        self.patchedROMCRC32 = patchedROMCRC32
        self.sourceURL = sourceURL
        self.releaseDate = releaseDate
        self.categories = categories
    }
}
