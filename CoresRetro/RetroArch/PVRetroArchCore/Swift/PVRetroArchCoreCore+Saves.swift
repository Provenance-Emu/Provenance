//
//  PVRetroArchCoreCore+Saves.swift
//  PVRetroArchCore
//
//  Async save/load uses the ObjC completion-handler path (background queue + RetroArch task drain),
//  avoiding synchronous `content_wait_for_*` on the caller thread (deadlock with `rarch_draw_observer`).
//

import Foundation
import PVEmulatorCore

extension PVRetroArchCoreCore {
    /// Async load that uses `loadStateFromFileAtPath:completionHandler:` so RetroArch waits off the caller thread.
    @objc public override func loadState(fromFileAtPath path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _bridge.loadState(fromFileAtPath: path, completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    /// Async save that uses `saveStateToFileAtPath:completionHandler:` so RetroArch waits off the caller thread.
    @objc public override func saveState(toFileAtPath path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _bridge.saveState(toFileAtPath: path, completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}
