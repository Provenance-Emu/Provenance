//
//  CodeSignatureUtils.swift
//
//
//  Created by Joseph Mattiello on 6/1/24.
//
// Created by Theodore Dubois on 2/28/20.
// Licensed under GNU General Public License 3.0

// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv3
// Refer to the license.txt file included.

import Foundation
import MachO
#if os(macOS)
import Security
#endif

let CS_EXECSEG_ALLOW_UNSIGNED: UInt64 = 0x10

/// Superblob magic (`CSMAGIC_EMBEDDED_SIGNATURE`).
private let kCSSuperblobMagic: UInt32 = 0xfade0cc0
/// Embedded DER entitlements blob (`CSMAGIC_EMBEDDED_ENTITLEMENT_DER`).
private let kCSEntitlementsDERMagic: UInt32 = 0xfade7171
/// Code directory blob (`CSMAGIC_CODEDIRECTORY`).
private let kCSCodeDirectoryMagic: UInt32 = 0xfade0c02

struct CSCodedirectory {
    var magic: UInt32
    var length: UInt32
    var version: UInt32
    var flags: UInt32
    var hashOffset: UInt32
    var identOffset: UInt32
    var specialSlots: UInt32
    var codeSlots: UInt32
    var codeLimit: UInt32
    var hashSize: UInt8
    var hashType: UInt8
    var platform: UInt8
    var pageSize: UInt8
    var spareTwo: UInt32

    var scatterOffset: UInt32

    var teamOffset: UInt32

    var spare3: UInt32
    var codeLimit64: UInt64

    var execSegmentBase: UInt64
    var execSegmentLimit: UInt64
    var execSegmentFlags: UInt64
}

private struct ParsedCodeSignature {
    let verifiedDirectory: Bool
    let entitlements: [String: Any]
}

/// Normalizes plist entitlement values (bool, `NSNumber`, or presence for string-style keys).
@available(iOS 13.4, tvOS 13.4, *)
private func entitlementPlistIndicatesEnabled(_ dict: [String: Any]?, key: String) -> Bool {
    guard let dict, let value = dict[key] else { return false }
    switch value {
    case let b as Bool:
        return b
    case let n as NSNumber:
        return n.boolValue
    case let s as String:
        return !s.isEmpty
    default:
        return false
    }
}

/// Extracts the signed provisioning plist payload from `embedded.mobileprovision` (XML or binary plist after the CMS wrapper).
/// Sideload / AltStore / enterprise installs keep this file in the app bundle; its `Entitlements` dict mirrors what was signed onto the app.
@available(iOS 13.4, tvOS 13.4, *)
private func entitlementsFromEmbeddedMobileProvision() -> [String: Any]? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else { return nil }
    guard let raw = try? Data(contentsOf: url), raw.count > 32 else { return nil }

    if let plistData = extractXMLPlistPayload(from: raw),
       let top = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
       let ents = top["Entitlements"] as? [String: Any] {
        return ents
    }

    if let bplistStart = firstSubdataIndex(of: Data("bplist00".utf8), in: raw) {
        let tail = raw[bplistStart...]
        if let top = try? PropertyListSerialization.propertyList(from: Data(tail), options: [], format: nil) as? [String: Any],
           let ents = top["Entitlements"] as? [String: Any] {
            return ents
        }
    }

    return nil
}

/// Locates an XML plist inside the provisioning profile blob (bytes preserved via ISO Latin-1).
@available(iOS 13.4, tvOS 13.4, *)
private func extractXMLPlistPayload(from raw: Data) -> Data? {
    guard let latin1 = String(data: raw, encoding: .isoLatin1) else { return nil }
    let openers = ["<?xml", "<plist version"]
    var start: String.Index?
    for tag in openers {
        if let r = latin1.range(of: tag) {
            if let existing = start {
                if r.lowerBound < existing { start = r.lowerBound }
            } else {
                start = r.lowerBound
            }
        }
    }
    guard let s = start, let end = latin1.range(of: "</plist>", range: s..<latin1.endIndex) else { return nil }
    return String(latin1[s..<end.upperBound]).data(using: .utf8)
}

/// First index where `needle` occurs in `haystack` (byte scan; avoids colliding with `Data` API additions).
@available(iOS 13.4, tvOS 13.4, *)
private func firstSubdataIndex(of needle: Data, in haystack: Data) -> Data.Index? {
    guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
    var i = haystack.startIndex
    let limit = haystack.index(haystack.endIndex, offsetBy: -needle.count + 1)
    while i < limit {
        if haystack[i..<haystack.index(i, offsetBy: needle.count)] == needle {
            return i
        }
        i = haystack.index(after: i)
    }
    return nil
}

/// Reads a boolean entitlement from the **running process** via `SecTask` (macOS only; not exposed on iOS/tvOS Swift SDKs).
/// - Returns: On embedded OS, always `nil` so ``HasBooleanEntitlement`` uses Mach-O / provisioning profile. On macOS, `true` / `false` / `nil` as documented.
@available(iOS 13.4, tvOS 13.4, *)
private func booleanEntitlementFromSecTask(_ entitlementKey: String) -> Bool? {
    #if os(macOS)
    guard let task = SecTaskCreateFromSelf(kCFAllocatorDefault) else { return nil }
    let key = entitlementKey as CFString
    guard let value = SecTaskCopyValueForEntitlement(task, key, nil) else {
        return false
    }
    if let b = value as? Bool {
        return b
    }
    if let n = value as? NSNumber {
        return n.boolValue
    }
    return nil
    #else
    _ = entitlementKey
    return nil
    #endif
}

/// Returns boolean entitlement values: `SecTask` on macOS, else Mach-O embedded signature, else `embedded.mobileprovision` `Entitlements` (sideload).
@available(iOS 13.4, tvOS 13.4, *)
func HasBooleanEntitlement(_ entitlementKey: String) -> Bool {
    switch booleanEntitlementFromSecTask(entitlementKey) {
    case .some(let value):
        return value
    case .none:
        break
    }
    if entitlementPlistIndicatesEnabled(parsedCodeSignature()?.entitlements, key: entitlementKey) {
        return true
    }
    return entitlementPlistIndicatesEnabled(entitlementsFromEmbeddedMobileProvision(), key: entitlementKey)
}

/// Reads a big-endian `UInt32` from `data` at `offset` (Mach-O code-signature fields are BE).
@available(iOS 13.4, tvOS 13.4, *)
private func bigEndianUInt32(in data: Data, offset: Int) -> UInt32? {
    guard offset >= 0, data.count >= offset + 4 else { return nil }
    return (UInt32(data[offset]) << 24)
        | (UInt32(data[offset + 1]) << 16)
        | (UInt32(data[offset + 2]) << 8)
        | UInt32(data[offset + 3])
}

/// Reads a big-endian `UInt64` from `data` at `offset`.
@available(iOS 13.4, tvOS 13.4, *)
private func bigEndianUInt64(in data: Data, offset: Int) -> UInt64? {
    guard offset >= 0, data.count >= offset + 8 else { return nil }
    var v: UInt64 = 0
    for b in 0..<8 {
        v = (v << 8) | UInt64(data[offset + b])
    }
    return v
}

/// Mach header for the main executable (image index 0). Avoids `dladdr(#function)` which can resolve to the wrong dylib in Swift.
@available(iOS 13.4, tvOS 13.4, *)
private func mainExecutableMachHeader64() -> UnsafePointer<mach_header_64>? {
    guard let mh = _dyld_get_image_header(0) else { return nil }
    let raw = UnsafeRawPointer(mh)
    guard raw.load(as: UInt32.self) == MH_MAGIC_64 else { return nil }
    return raw.assumingMemoryBound(to: mach_header_64.self)
}

@available(iOS 13.4, tvOS 13.4, *)
private func parsedCodeSignature() -> ParsedCodeSignature? {
    guard let header = mainExecutableMachHeader64() else {
        return nil
    }
    let base = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(header))
    var lc = base + MemoryLayout<mach_header_64>.size
    var csLc: UnsafeMutablePointer<linkedit_data_command>?
    for _ in 0..<header.pointee.ncmds {
        let loadCommand = lc.assumingMemoryBound(to: load_command.self)
        if loadCommand.pointee.cmd == LC_CODE_SIGNATURE {
            csLc = UnsafeMutableRawPointer(lc).assumingMemoryBound(to: linkedit_data_command.self)
            break
        }
        lc += Int(loadCommand.pointee.cmdsize)
    }
    guard let linkeditDataCommand = csLc else {
        return nil
    }

    guard let executableURL = Bundle.main.executableURL else {
        return nil
    }
    guard let fileHandle = try? FileHandle(forReadingFrom: executableURL) else {
        return nil
    }
    defer {
        fileHandle.closeFile()
    }

    fileHandle.seek(toFileOffset: UInt64(linkeditDataCommand.pointee.dataoff))

    guard let csData = try? fileHandle.read(upToCount: Int(linkeditDataCommand.pointee.datasize)) else {
        return nil
    }

    /// Parse a `CS_SuperBlob` without `load(as:)` — a Swift `[CSBlobIndex]` is **not** layout-compatible with the on-disk
    /// trailing index table; treating Mach-O bytes as one caused invalid `objc_retain` under the debugger on recent OS builds.
    guard csData.count >= 12,
          let sbMagic = bigEndianUInt32(in: csData, offset: 0),
          sbMagic == kCSSuperblobMagic,
          let sbLength = bigEndianUInt32(in: csData, offset: 4),
          let blobCount = bigEndianUInt32(in: csData, offset: 8)
    else {
        return nil
    }
    let superblobTotal = Int(sbLength)
    guard superblobTotal >= 12, superblobTotal <= csData.count else { return nil }
    guard blobCount <= 64 else { return nil }
    let indexTableEnd = 12 + Int(blobCount) * 8
    guard csData.count >= indexTableEnd else { return nil }

    var verifiedDirectory = false
    var entitlementsData: Data?

    for i in 0..<Int(blobCount) {
        let entryBase = 12 + i * 8
        guard let blobOffset = bigEndianUInt32(in: csData, offset: entryBase + 4) else { continue }
        let genericOffset = Int(blobOffset)
        guard genericOffset >= 0, genericOffset + 8 <= csData.count else { continue }
        guard let magic = bigEndianUInt32(in: csData, offset: genericOffset),
              let blobLength = bigEndianUInt32(in: csData, offset: genericOffset + 4)
        else { continue }
        let blobEnd = genericOffset + Int(blobLength)
        guard blobEnd <= csData.count, blobEnd >= genericOffset + 8 else { continue }

        if magic == kCSEntitlementsDERMagic {
            let payloadStart = genericOffset + 8
            entitlementsData = csData.subdata(in: payloadStart..<blobEnd)
        } else if magic == kCSCodeDirectoryMagic {
            guard let verRel = MemoryLayout<CSCodedirectory>.offset(of: \.version),
                  let execRel = MemoryLayout<CSCodedirectory>.offset(of: \.execSegmentFlags)
            else { continue }
            let versionOffset = genericOffset + verRel
            let execFlagsOffset = genericOffset + execRel
            guard execFlagsOffset + 8 <= blobEnd, versionOffset + 4 <= blobEnd,
                  let version = bigEndianUInt32(in: csData, offset: versionOffset),
                  let execSegmentFlags = bigEndianUInt64(in: csData, offset: execFlagsOffset)
            else { continue }

            if version < 0x20400 {
                let error = "CodeDirectory version is 0x\(String(version, radix: 16)). Should be 0x20400 or higher."
                DispatchQueue.main.async { DOLJitManager.shared.setAuxiliaryError(error) }
                continue
            }

            if (execSegmentFlags & CS_EXECSEG_ALLOW_UNSIGNED) != CS_EXECSEG_ALLOW_UNSIGNED {
                let error = "CS_EXECSEG_ALLOW_UNSIGNED is not set. The current executable segment flags are 0x\(String(execSegmentFlags, radix: 16))."
                DispatchQueue.main.async { DOLJitManager.shared.setAuxiliaryError(error) }
                continue
            }

            verifiedDirectory = true
        }
    }

    guard let entitlements = entitlementsData else {
        DispatchQueue.main.async { DOLJitManager.shared.setAuxiliaryError("Could not find entitlements data within the code signature.") }
        return nil
    }

    guard let entitlementsDict = try? PropertyListSerialization.propertyList(from: entitlements, options: [], format: nil) as? [String: Any] else {
        DispatchQueue.main.async { DOLJitManager.shared.setAuxiliaryError("Entitlement data parsing failed.") }
        return nil
    }

    return ParsedCodeSignature(verifiedDirectory: verifiedDirectory, entitlements: entitlementsDict)
}

@available(iOS 13.4, tvOS 13.4, *)
func HasValidCodeSignature() -> Bool {
    guard let signature = parsedCodeSignature() else {
        return false
    }

    let hasGetTaskAllow = entitlementPlistIndicatesEnabled(signature.entitlements, key: "get-task-allow")
        || entitlementPlistIndicatesEnabled(entitlementsFromEmbeddedMobileProvision(), key: "get-task-allow")
    guard hasGetTaskAllow else {
        DispatchQueue.main.async { DOLJitManager.shared.setAuxiliaryError("get-task-allow entitlement is not set to true.") }
        return false
    }

    return signature.verifiedDirectory
}
