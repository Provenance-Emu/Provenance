//
//  PatchableCore.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// A protocol adopted by emulator cores that support loading ROM patches natively.
///
/// Cores conforming to `PatchableCore` can receive both the ROM URL and the patch URL
/// at launch time, delegating the actual patching to the emulator's built-in logic.
/// This is preferred over pre-applying the patch to a temp file when supported.
///
/// Cores that do NOT conform to this protocol will have patches pre-applied by
/// `PatchApplier` before the patched ROM is handed to the core.
///
/// ## Example
/// ```swift
/// final class MGBACore: PVEmulatorCore, PatchableCore {
///     static var supportedPatchFormats: [PatchFormat] {
///         [.ips, .ups, .bps]
///     }
/// }
/// ```
public protocol PatchableCore: AnyObject {
    /// The patch formats this core can load natively.
    static var supportedPatchFormats: [PatchFormat] { get }
}

public extension PatchableCore {
    /// Returns `true` if this core supports the given patch format natively.
    static func supports(format: PatchFormat) -> Bool {
        supportedPatchFormats.contains(format)
    }
}

/// Errors that can occur during patch operations.
public enum PatchError: Error, LocalizedError, Sendable {
    case unsupportedFormat(String)
    case corruptPatchFile(String)
    case crcMismatch(expected: UInt32, actual: UInt32)
    case sourceROMMismatch
    case patchedROMVerificationFailed
    case patchFileNotFound(URL)
    case sourceROMNotFound(URL)
    case outputWriteFailed(Error)
    case patchApplicationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported patch format: \(ext)"
        case .corruptPatchFile(let reason):
            return "Corrupt patch file: \(reason)"
        case .crcMismatch(let expected, let actual):
            return String(format: "CRC mismatch: expected 0x%08X, got 0x%08X", expected, actual)
        case .sourceROMMismatch:
            return "The ROM does not match the patch's target ROM"
        case .patchedROMVerificationFailed:
            return "Patched ROM verification failed"
        case .patchFileNotFound(let url):
            return "Patch file not found: \(url.lastPathComponent)"
        case .sourceROMNotFound(let url):
            return "Source ROM not found: \(url.lastPathComponent)"
        case .outputWriteFailed(let error):
            return "Failed to write patched ROM: \(error.localizedDescription)"
        case .patchApplicationFailed(let reason):
            return "Patch application failed: \(reason)"
        }
    }
}
