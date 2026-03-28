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

let CS_EXECSEG_ALLOW_UNSIGNED: UInt64 = 0x10

struct CSBlobIndex {
    var type: UInt32
    var offset: UInt32
}

struct CSSuperblob {
    var magic: UInt32
    var length: UInt32
    var count: UInt32
    var index: [CSBlobIndex]
}

struct CSGeneric {
    var magic: UInt32
    var length: UInt32
}

struct CSEntitlements {
    var magic: UInt32
    var length: UInt32
    var entitlements: [CChar]
}

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

/// Returns boolean entitlement values parsed from the main executable's code signature.
@available(iOS 13.4, tvOS 13.4, *)
func HasBooleanEntitlement(_ entitlementKey: String) -> Bool {
    guard let entitlements = parsedCodeSignature()?.entitlements else {
        return false
    }

    return entitlements[entitlementKey] as? Bool == true
}

@available(iOS 13.4, tvOS 13.4, *)
private func parsedCodeSignature() -> ParsedCodeSignature? {
    var info = Dl_info()
    guard dladdr(#function, &info) != 0, let base = info.dli_fbase else {
        return nil
    }

    let header = base.assumingMemoryBound(to: mach_header_64.self)
    guard header.pointee.magic == MH_MAGIC_64 else {
        return nil
    }

    var csLc: UnsafeMutablePointer<linkedit_data_command>?
    var lc = UnsafeMutableRawPointer(base + MemoryLayout<mach_header_64>.size)
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

    let cs = csData.withUnsafeBytes { $0.load(as: CSSuperblob.self) }
    guard UInt32(bigEndian: cs.magic) == 0xfade0cc0 else {
        return nil
    }

    var verifiedDirectory = false
    var entitlementsData: Data?

    for i in 0..<UInt32(bigEndian: cs.count) {
        let genericOffset = UInt32(bigEndian: cs.index[Int(i)].offset)
        let generic = csData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> CSGeneric in
            let genericPtr = ptr.baseAddress! + Int(genericOffset)
            return genericPtr.assumingMemoryBound(to: CSGeneric.self).pointee
        }
        let magic = UInt32(bigEndian: generic.magic)

        if magic == 0xfade7171 {
            let ents = csData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> CSEntitlements in
                let entsPtr = ptr.baseAddress! + Int(genericOffset)
                return entsPtr.assumingMemoryBound(to: CSEntitlements.self).pointee
            }
            let length = UInt32(bigEndian: ents.length) - UInt32(MemoryLayout<CSEntitlements>.offset(of: \.entitlements)!)
            entitlementsData = csData.subdata(in: Int(genericOffset + UInt32(MemoryLayout<CSEntitlements>.offset(of: \.entitlements)!))..<Int(genericOffset + length))
        } else if magic == 0xfade0c02 {
            let directory = csData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> CSCodedirectory in
                let directoryPtr = ptr.baseAddress! + Int(genericOffset)
                return directoryPtr.assumingMemoryBound(to: CSCodedirectory.self).pointee
            }
            let version = UInt32(bigEndian: directory.version)
            let execSegmentFlags = UInt64(bigEndian: directory.execSegmentFlags)

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

    guard signature.entitlements["get-task-allow"] as? Bool == true else {
        DispatchQueue.main.async { DOLJitManager.shared.setAuxiliaryError("get-task-allow entitlement is not set to true.") }
        return false
    }

    return signature.verifiedDirectory
}
