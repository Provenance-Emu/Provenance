//
//  LibraryArtworkShape.swift
//  PVLibrarySnapshotConfig
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// The aspect a system's box art is expected to have.
///
/// Extensions map this onto their own presentation type (Top Shelf maps it to
/// `TVTopShelfSectionedItem.ImageShape`).  Deciding it here — rather than in
/// each extension — keeps the system-identifier table in one place.
public enum LibraryArtworkShape: String, Sendable, CaseIterable {
    /// Cartridge/handheld art, roughly 1:1.
    case square
    /// Landscape box art, roughly 16:9.
    case wide
}

public extension LibraryArtworkShape {
    /// Systems whose box art is landscape rather than square.
    ///
    /// These strings mirror `SystemIdentifier.rawValue` in the PVSystems
    /// package.  They are duplicated here **on purpose**: PVLibrarySnapshotConfig
    /// must stay light so app extensions can link it without pulling in
    /// PVSystems, PVLibrary or Realm.  Keep this set in
    /// sync when system identifiers change — `LibraryArtworkShapeTests` guards
    /// the format, not the membership.
    private static let wideSystemIdentifiers: Set<String> = [
        "com.provenance.snes",
        "com.provenance.nes",
        "com.provenance.genesis",
        "com.provenance.mastersystem",
        "com.provenance.n64",
        "com.provenance.5200",
        "com.provenance.7800",
        "com.provenance.jaguar",
        "com.provenance.jaguarcd",
        "com.provenance.psx",
        "com.provenance.saturn",
        "com.provenance.dreamcast",
        "com.provenance.ps2",
        "com.provenance.ps3",
        "com.provenance.gamecube",
        "com.provenance.wii"
    ]

    /// Resolves the expected art shape for a reverse-DNS system identifier.
    /// Unknown or missing identifiers fall back to `.square`, matching the
    /// previous Top Shelf behaviour.
    static func shape(forSystemIdentifier identifier: String?) -> LibraryArtworkShape {
        guard let identifier, wideSystemIdentifiers.contains(identifier) else { return .square }
        return .wide
    }
}
