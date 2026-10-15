//
//  SystemMap.swift
//  PVLibrarySharing
//
//  Maps each peer app's platform strings to Provenance system ids (spec §3.3).
//

import Foundation
import PVSystems

/// Maps a peer app's wire platform value to a `SystemIdentifier`.
///
/// | App   | Wire value                                        | System                            |
/// |-------|---------------------------------------------------|-----------------------------------|
/// | iFly  | "Dreamcast", "Naomi", "Naomi 2", "Atomiswave"     | Dreamcast, NAOMI, NAOMI2, Atomiswave |
/// | iCube | `gc` / "GameCube", `wii` / "Wii"                  | GameCube, Wii                     |
///
/// Matching is case-insensitive and ignores spaces, so iFly's "Naomi2"
/// spelling and its lower-case session-advert values ("dreamcast") map too.
/// An unknown value maps to nil: the item shows as not supported.
public enum SystemMap {

    public static func systemIdentifier(forPlatform platform: String, app: PeerApp) -> SystemIdentifier? {
        let key = normalize(platform)
        switch app {
        case .iFly: return iFlyPlatforms[key]
        case .iCube: return iCubePlatforms[key]
        case .pvLibrary, .contentServer: return systemIdentifier(compact: platform)
        }
    }

    /// Every system a peer app can serve. Used to decide whether a peer is
    /// worth listing before its catalogue is fetched.
    public static func systems(servedBy app: PeerApp) -> Set<SystemIdentifier> {
        switch app {
        case .iFly: return Set(iFlyPlatforms.values)
        case .iCube: return Set(iCubePlatforms.values)
        case .pvLibrary, .contentServer: return Set(SystemIdentifier.allCases).subtracting([.Unknown])
        }
    }

    // MARK: - Dotted ids (v1.1)

    static let dottedPrefix = "com.provenance."

    /// A dotted id (`com.provenance.dreamcast`) or its compact TXT form
    /// (`dreamcast`), case-insensitively.
    public static func systemIdentifier(compact value: String) -> SystemIdentifier? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let dotted = trimmed.lowercased().hasPrefix(dottedPrefix) ? trimmed : dottedPrefix + trimmed
        if let exact = SystemIdentifier(rawValue: dotted) { return exact }
        return SystemIdentifier.allCases.first { $0.rawValue.caseInsensitiveCompare(dotted) == .orderedSame }
    }

    /// `com.provenance.dreamcast` → `dreamcast`, the TXT `sys` form.
    public static func compact(_ system: SystemIdentifier) -> String {
        system.rawValue.hasPrefix(dottedPrefix) ? String(system.rawValue.dropFirst(dottedPrefix.count)) : system.rawValue
    }

    // MARK: - Tables

    private static let iFlyPlatforms: [String: SystemIdentifier] = [
        "dreamcast": .Dreamcast,
        "naomi": .NAOMI,
        "naomi2": .NAOMI2,
        "atomiswave": .Atomiswave
    ]

    private static let iCubePlatforms: [String: SystemIdentifier] = [
        "gc": .GameCube,
        "gamecube": .GameCube,
        "wii": .Wii
    ]

    private static func normalize(_ platform: String) -> String {
        platform.lowercased().filter { !$0.isWhitespace }
    }
}
