//
//  ApplyTypes.swift
//  PVPatchEngine
//
//  Inputs and outputs shared by the per-format appliers.
//

import Foundation

struct ApplyInputs {
    let patch: PosixFile
    let source: PosixFile
    let output: PosixFile
    let options: PatchOptions
    let context: WorkContext
}

struct ApplyOutcome {
    var bytesWritten: UInt64
    var verified: [VerifiedChecksum] = []
    var ignoredTargetMismatch: ChecksumMismatch?
}
