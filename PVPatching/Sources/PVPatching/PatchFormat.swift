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
    /// A `.xdelta` / `.delta` patch. Files with this extension are almost always xdelta3
    /// (VCDIFF) and are applied as such; true xdelta 1 files are refused by their magic bytes.
    case xdelta
    /// xdelta version 3 binary delta patches (VCDIFF, RFC 3284).
    case xdelta3
    /// PlayStation Patch Format — used for PSX patches.
    case ppf
    /// APS (Automatic Patching System) — older N64 format.
    case aps
    /// RUP (Real Universal Patcher) format.
    case rup
    /// NSP (N64 split patch) format.
    case nsp

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
        case .nsp:     return ["nsp"]
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
        case .nsp:     return "NSP"
        }
    }

    /// Whether this format includes a CRC/hash check for the target ROM.
    public var hasIntegrityCheck: Bool {
        switch self {
        case .bps, .ups, .ppf, .xdelta, .xdelta3: return true
        case .ips, .ips32, .aps, .rup, .nsp: return false
        }
    }

    /// Whether `PatchApplier` can actually apply this format today.
    /// Formats that are declared but still throw `unsupportedFormat` return false.
    public var isImplemented: Bool {
        switch self {
        case .ips, .ips32, .bps, .ups, .ppf, .xdelta, .xdelta3: return true
        case .aps, .rup, .nsp: return false
        }
    }

    /// Lowercased file extensions (without dot) of every format the applier can apply.
    /// Single source of truth for file pickers, folder scanners and tool registries.
    public static let implementedFileExtensions: Set<String> = Set(
        allCases.filter(\.isImplemented).flatMap(\.fileExtensions)
    )

    /// Detect a patch format from the first bytes of a file, independent of its name.
    /// Returns nil for unknown or archive content.
    public static func detect(fromMagic data: Data) -> PatchFormat? {
        guard data.count >= 5 else { return nil }
        let head = data.prefix(5)
        if head.elementsEqual("PATCH".utf8) { return .ips }
        if head.prefix(4).elementsEqual("BPS1".utf8) { return .bps }
        if head.prefix(4).elementsEqual("UPS1".utf8) { return .ups }
        if head.prefix(3).elementsEqual("PPF".utf8) { return .ppf }
        if head.prefix(5).elementsEqual("IPS32".utf8) { return .ips32 }
        if head.prefix(3) == Data([0xD6, 0xC3, 0xC4]) { return .xdelta3 }
        return nil
    }

    /// Detect the format of a patch file from its magic bytes, falling back to its extension
    /// for formats PVPatchEngine does not read. A `.xdelta` file with a VCDIFF header is `.xdelta`;
    /// a VCDIFF file under any other name is `.xdelta3`.
    public static func detect(fileAt url: URL) -> PatchFormat? {
        let byName = detect(from: url)
        return EngineBridge.detect(fileAt: url, nameHint: byName) ?? byName
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
