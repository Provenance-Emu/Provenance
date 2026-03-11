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

    /// Waits for a file to become stable (no active writes) using
    /// kqueue-based dispatch source monitoring.
    ///
    /// - Parameters:
    ///   - url: The file URL to monitor.
    ///   - quiesceInterval: Seconds the file must be quiet to be
    ///     considered stable. Defaults to 0.3 s.
    ///   - timeout: Maximum seconds to wait before giving up.
    ///     Defaults to 10 s.
    /// - Returns: `true` if the file became stable within `timeout`,
    ///   `false` if the timeout was reached first.
    static func waitForStability(
        at url: URL,
        quiesceInterval: TimeInterval = 0.3,
        timeout: TimeInterval = 10.0
    ) async -> Bool {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            WLOG("FileStabilityChecker: Cannot open file descriptor for \(url.lastPathComponent)")
            return false
        }

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(
                label: "org.provenance-emu.file-stability.\(UUID().uuidString)"
            )
            var hasResumed = false

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib],
                queue: queue
            )

            var stabilityTimer: DispatchWorkItem?
            var timeoutTimer: DispatchWorkItem?

            /// Thread-safe single-shot resume helper.
            let finish: (Bool) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                stabilityTimer?.cancel()
                timeoutTimer?.cancel()
                source.cancel()
                continuation.resume(returning: result)
            }

            /// Resets the quiesce timer. After `quiesceInterval` with no
            /// further events the file is declared stable.
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

            // Cancellable hard timeout to avoid waiting forever.
            let hardTimeout = DispatchWorkItem {
                WLOG("FileStabilityChecker: Timed out waiting for \(url.lastPathComponent) to stabilize")
                finish(false)
            }
            timeoutTimer = hardTimeout
            queue.asyncAfter(deadline: .now() + timeout, execute: hardTimeout)

            source.resume()
            scheduleQuiesceTimer()
        }
    }
}
