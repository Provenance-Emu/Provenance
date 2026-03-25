//
//  PatchFormat.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Supported ROM patch file formats.
public enum PatchFormat: String, CaseIterable, Sendable, Codable, Identifiable {
    /// International Patching System — classic format for ROMs up to 16 MB.
    case ips
    /// IPS32 — large-ROM extension of IPS using 4-byte offsets and "EEOF" terminator.
    case ips32
    /// Beat Patch System — successor to IPS; includes CRC verification.
    case bps
    /// Universal Patch System — bidirectional patching with CRC.
    case ups
    /// xdelta version 1/2 binary delta patches.
    case xdelta
    /// xdelta version 3 binary delta patches.
    case xdelta3
    /// PlayStation Patch Format — used for PSX patches.
    case ppf
    /// APS (Automatic Patching System) — older N64 format.
    case aps
    /// RUP (Real Universal Patcher) format.
    case rup

    public var id: String { rawValue }

    /// File extensions associated with this format (lowercase, without leading dot).
    public var fileExtensions: [String] {
        switch self {
        case .ips:     return ["ips"]
        case .ips32:   return ["ips32"]
        case .bps:     return ["bps"]
        case .ups:     return ["ups"]
        case .xdelta:  return ["xdelta", "delta"]
        case .xdelta3: return ["xdelta3", "vcdiff"]
        case .ppf:     return ["ppf"]
        case .aps:     return ["aps"]
        case .rup:     return ["rup"]
        }
    }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .ips:     return "IPS"
        case .ips32:   return "IPS32"
        case .bps:     return "BPS (Beat)"
        case .ups:     return "UPS"
        case .xdelta:  return "xdelta"
        case .xdelta3: return "xdelta3"
        case .ppf:     return "PPF"
        case .aps:     return "APS"
        case .rup:     return "RUP"
        }
    }

    /// Whether this format includes a CRC/hash check for the target ROM.
    public var hasIntegrityCheck: Bool {
        switch self {
        case .bps, .ups, .ppf, .xdelta3: return true
        case .ips, .ips32, .xdelta, .aps, .rup: return false
        }
    }

    /// Detect patch format from a file URL based on its extension.
    public static func detect(from url: URL) -> PatchFormat? {
        let ext = url.pathExtension.lowercased()
        return allCases.first { $0.fileExtensions.contains(ext) }
    }

    /// All file extensions across all known formats.
    public static var allFileExtensions: Set<String> {
        Set(allCases.flatMap(\.fileExtensions))
    }
}
