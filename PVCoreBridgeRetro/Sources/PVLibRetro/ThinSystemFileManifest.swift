//
//  ThinSystemFileManifest.swift
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-05-29.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Declarative table mapping thin-wrapper libretro core-id substrings to the
//  auxiliary "system" asset archives they need from the libretro buildbot.
//
//  These are NOT console BIOS files (those flow through the existing
//  BIOSPath / CloudKit BIOS path) — they are core-engine assets that ship
//  on the buildbot assets host: PPSSPP fonts/flash0, EcWolf's ecwolf.pk3,
//  PrBoom's prboom.wad, etc.
//
//  The manifest drives `ThinSystemFileProvisioner`. Adding a core is a matter
//  of appending an entry here — there is no per-core download code.
//
//  Provisioning is tracked with a per-core version-stamp sentinel
//  (`<systemDir>/.pv_assets_<core>.stamp`) rather than knowledge of the
//  archive's internal layout: once a core's archive has been successfully
//  extracted, the stamp is written and subsequent launches skip the download.
//

import Foundation

// MARK: - Required asset entry

/// A single asset archive a thin-wrapper core needs at runtime.
///
/// Every entry is a ZIP on the libretro buildbot assets host. The archive is
/// extracted directly into the resolved system directory (the same directory
/// the core sees via `RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY`).
struct ThinSystemAsset: Sendable, Equatable {
    /// Absolute URL of the ZIP on the buildbot assets host.
    let sourceURL: URL
    /// Human-readable core name used in the user-facing toast
    /// ("Downloading <displayName> system files…").
    let displayName: String
}

// MARK: - Manifest

/// Declarative catalogue of buildbot system-asset archives, keyed by a
/// lowercase core-id substring match.
enum ThinSystemFileManifest {

    /// Buildbot assets host. All entries are `<systemBaseURL>/<Name>.zip`,
    /// where `<Name>` is URL-encoded (spaces / parens become `%20` / `%28`…).
    static let systemBaseURL = "https://buildbot.libretro.com/assets/system"

    /// A manifest row: the lowercase substring to match against the core id,
    /// plus the assets that core requires.
    struct Entry: Sendable {
        /// Substrings tested against the lowercase core id (any match wins).
        let coreIDSubstrings: [String]
        /// A short identifier used to name the stamp file
        /// (`.pv_assets_<stampKey>.stamp`). Stable across releases.
        let stampKey: String
        /// The asset archives this core needs.
        let assets: [ThinSystemAsset]
    }

    /// Build an absolute buildbot asset URL from a pre-encoded file name.
    /// `encodedFileName` must already be percent-encoded for the path
    /// (e.g. `"MAME%202003-Plus.zip"`). Returns `nil` only if the combined
    /// string is somehow not a valid URL (never expected for the static table).
    private static func assetURL(_ encodedFileName: String) -> URL? {
        URL(string: "\(systemBaseURL)/\(encodedFileName)")
    }

    /// Build a single-archive asset list, skipping any entry whose URL fails
    /// to construct (keeps the static table total — no force-unwraps).
    private static func asset(_ encodedFileName: String, displayName: String) -> [ThinSystemAsset] {
        guard let url = assetURL(encodedFileName) else { return [] }
        return [ThinSystemAsset(sourceURL: url, displayName: displayName)]
    }

    /// The full catalogue. Ordered so that more specific matches (e.g.
    /// `mame2003`) are checked before broader ones (`mame`); `entry(forCoreID:)`
    /// returns the first match.
    static var entries: [Entry] {
        [
            // PPSSPP — PSP engine assets (fonts / flash0 / ppge_atlas).
            Entry(coreIDSubstrings: ["ppsspp"],
                  stampKey: "ppsspp",
                  assets: asset("PPSSPP.zip", displayName: "PPSSPP")),

            // EcWolf — Wolfenstein 3D engine needs ecwolf.pk3.
            Entry(coreIDSubstrings: ["ecwolf"],
                  stampKey: "ecwolf",
                  assets: asset("ECWolf.zip", displayName: "EcWolf")),

            // PrBoom — Doom engine needs prboom.wad.
            Entry(coreIDSubstrings: ["prboom"],
                  stampKey: "prboom",
                  assets: asset("PrBoom.zip", displayName: "PrBoom"))

            // NOTE: the buildbot also hosts assets for blueMSX, FinalBurn Neo,
            // MAME 2003/2003-Plus, XRick, ScummVM, etc. (see the design doc's
            // "Confirmed inputs" list). They are intentionally NOT added here yet:
            // adding a core requires confirming both the exact archive name AND
            // its extraction layout (root vs. a `<core>/` subdir). All three
            // entries above extract to the system-dir root, which `ThinSystemAsset`
            // currently assumes. Cores whose archives need a subdir (e.g. the
            // legacy `fbalpha2012_neogeo.zip` → `fbneo/`) are still served by the
            // legacy `LibretroBuildbot` path in PVThinLibretroCore+SystemFiles.swift
            // until `ThinSystemAsset` grows a destination-subdir field.
        ]
    }

    /// Returns the first manifest entry whose substring list matches `coreID`.
    /// `coreID` is matched case-insensitively. Returns `nil` when no core asset
    /// pack is registered (the common case — the provisioner then no-ops).
    static func entry(forCoreID coreID: String) -> Entry? {
        let lowered = coreID.lowercased()
        guard !lowered.isEmpty else { return nil }
        return entries.first { entry in
            entry.coreIDSubstrings.contains { lowered.contains($0) }
        }
    }

    /// File name of the provisioning sentinel stamp for a given stamp key.
    /// Lives at `<systemDir>/.pv_assets_<stampKey>.stamp`.
    static func stampFileName(forStampKey stampKey: String) -> String {
        ".pv_assets_\(stampKey).stamp"
    }
}
