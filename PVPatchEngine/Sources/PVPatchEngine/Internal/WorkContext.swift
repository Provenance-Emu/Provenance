//
//  WorkContext.swift
//  PVPatchEngine
//
//  Cancellation and progress shared by every applier.
//

import Foundation

/// Set from the task cancellation handler, polled between chunks by the worker thread.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

final class WorkContext {
    /// Chunk size for streamed copies, checksum passes and sequential output.
    static let chunkSize = 2 * 1024 * 1024

    private let flag: CancelFlag
    private let report: (@Sendable (PatchProgress) -> Void)?
    private var plannedUnits: UInt64 = 0
    private var doneUnits: UInt64 = 0
    private var lastReported = -1.0
    var phase: PatchProgress.Phase = .verifying

    init(cancelFlag: CancelFlag, progress: (@Sendable (PatchProgress) -> Void)?) {
        flag = cancelFlag
        report = progress
    }

    func checkCancelled() throws {
        if flag.isCancelled { throw PatchError.cancelled }
    }

    /// Adds expected work, in bytes. Call before the work it describes starts.
    func plan(_ units: UInt64) {
        plannedUnits += units
    }

    /// Records finished work, in bytes, and checks for cancellation.
    func advance(_ units: UInt64) throws {
        doneUnits += units
        try checkCancelled()
        guard let report, plannedUnits > 0 else { return }
        let fraction = min(Double(doneUnits) / Double(plannedUnits), 1)
        if fraction - lastReported >= 0.001 {
            lastReported = fraction
            report(PatchProgress(phase: phase, fractionCompleted: fraction))
        }
    }

    func finish() {
        report?(PatchProgress(phase: .patching, fractionCompleted: 1))
    }
}
