//
//  FileStabilityChecker.swift
//  PVLibrary
//
//  Created by Provenance Contributors on 2026-03-11.
//

import Foundation
import PVLogging

/// Uses kqueue-based `DispatchSource` monitoring to determine when a file
/// has finished being written. This replaces fixed-interval polling delays
/// with event-driven detection: a dispatch source watches for `.write`,
/// `.extend`, and `.attrib` vnode events and resets a quiesce timer on
/// each event. The file is considered stable once no events arrive for
/// `quiesceInterval` seconds, or the overall `timeout` is exceeded.
enum FileStabilityChecker {

    /// Shared serial queue for all stability checks. Per-call state is
    /// kept in the closure, so a single queue is sufficient.
    private static let queue = DispatchQueue(
        label: "org.provenance-emu.file-stability"
    )

    /// Shared mutable reference so `withTaskCancellationHandler`'s
    /// `onCancel` closure can trigger the same teardown path.
    private final class CancelRef: @unchecked Sendable {
        var finish: ((Bool) -> Void)?
    }

    /// Waits for a file to become stable (no active writes) using
    /// kqueue-based dispatch source monitoring.
    ///
    /// - Parameters:
    ///   - url: The file URL to monitor.
    ///   - quiesceInterval: Seconds the file must be quiet to be
    ///     considered stable. Defaults to 0.3 s.
    ///   - timeout: Maximum seconds to wait before giving up.
    ///     Defaults to 10 s.
    /// - Returns: `true` if the file became stable within `timeout`.
    ///   `false` if the timeout was reached or the enclosing `Task`
    ///   was cancelled. When the file descriptor cannot be opened
    ///   (e.g. sandbox/permissions), returns `true` optimistically
    ///   so callers proceed to their own readability checks.
    static func waitForStability(
        at url: URL,
        quiesceInterval: TimeInterval = 0.3,
        timeout: TimeInterval = 10.0
    ) async -> Bool {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            let code = errno
            WLOG("FileStabilityChecker: open(\(url.lastPathComponent)) failed — "
                 + "errno \(code) (\(String(cString: strerror(code)))); "
                 + "proceeding optimistically")
            return true
        }

        let cancelRef = CancelRef()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var hasResumed = false

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .attrib],
                    queue: queue
                )

                var stabilityTimer: DispatchWorkItem?
                var timeoutTimer: DispatchWorkItem?

                let finish: (Bool) -> Void = { result in
                    queue.async {
                        guard !hasResumed else { return }
                        hasResumed = true
                        stabilityTimer?.cancel()
                        timeoutTimer?.cancel()
                        source.cancel()
                        continuation.resume(returning: result)
                    }
                }

                cancelRef.finish = finish

                if Task.isCancelled {
                    ILOG("FileStabilityChecker: Already cancelled for \(url.lastPathComponent)")
                    finish(false)
                    return
                }

                func scheduleQuiesceTimer() {
                    stabilityTimer?.cancel()
                    let timer = DispatchWorkItem {
                        ILOG("FileStabilityChecker: \(url.lastPathComponent) stable (no writes for \(quiesceInterval)s)")
                        finish(true)
                    }
                    stabilityTimer = timer
                    queue.asyncAfter(
                        deadline: .now() + quiesceInterval,
                        execute: timer
                    )
                }

                source.setEventHandler {
                    VLOG("FileStabilityChecker: Write activity on \(url.lastPathComponent), resetting timer")
                    scheduleQuiesceTimer()
                }

                source.setCancelHandler {
                    close(fd)
                }

                let hardTimeout = DispatchWorkItem {
                    WLOG("FileStabilityChecker: Timed out waiting for \(url.lastPathComponent) to stabilize")
                    finish(false)
                }
                timeoutTimer = hardTimeout
                queue.asyncAfter(deadline: .now() + timeout, execute: hardTimeout)

                source.resume()
                scheduleQuiesceTimer()
            }
        } onCancel: {
            ILOG("FileStabilityChecker: Task cancelled for \(url.lastPathComponent)")
            cancelRef.finish?(false)
        }
    }
}
