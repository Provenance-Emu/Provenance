//
//  PVSignpost.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 2025.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//
//  Lightweight wrappers around `os.signpost` for profiling performance-critical
//  sections such as frame timing and audio processing. Calls compile away to
//  nothing in release builds when the SIGNPOSTS_ENABLED flag is absent.
//

#if canImport(OSLog)
import OSLog

/// A set of pre-configured OSLog instances used exclusively for signpost intervals.
/// Each instance corresponds to a performance domain visible in Instruments.
public enum PVSignpostLog {
    /// Frame render timing (emulator display loop).
    public static let frame = OSLog(subsystem: os.Logger.provenanceSubsystem, category: .pointsOfInterest)

    /// Audio callback timing (core audio processing).
    public static let audio = OSLog(subsystem: os.Logger.provenanceSubsystem, category: .pointsOfInterest)

    /// ROM load / library scan timing.
    public static let library = OSLog(subsystem: os.Logger.provenanceSubsystem, category: .pointsOfInterest)
}

// MARK: - Signpost Helpers

/// Begin a named signpost interval.
///
/// Pair with `signpostEnd(_:name:id:)` using the same `log`, `name`, and `id`.
///
/// Example:
/// ```swift
/// let id = OSSignpostID(log: PVSignpostLog.frame)
/// signpostBegin(PVSignpostLog.frame, name: "renderFrame", id: id)
/// // ... work ...
/// signpostEnd(PVSignpostLog.frame, name: "renderFrame", id: id)
/// ```
@inlinable
public func signpostBegin(_ log: OSLog, name: StaticString, id: OSSignpostID = .exclusive) {
    os_signpost(.begin, log: log, name: name, signpostID: id)
}

/// End a named signpost interval previously started with `signpostBegin`.
@inlinable
public func signpostEnd(_ log: OSLog, name: StaticString, id: OSSignpostID = .exclusive) {
    os_signpost(.end, log: log, name: name, signpostID: id)
}

/// Emit a point-of-interest signpost (instantaneous event, not an interval).
@inlinable
public func signpostEvent(_ log: OSLog, name: StaticString) {
    os_signpost(.event, log: log, name: name)
}

/// Measure a synchronous block and emit begin/end signposts around it.
///
/// Example:
/// ```swift
/// let result = withSignpost(PVSignpostLog.frame, name: "renderFrame") {
///     renderer.render(frame)
/// }
/// ```
@inlinable
@discardableResult
public func withSignpost<T>(_ log: OSLog, name: StaticString, id: OSSignpostID = .exclusive, execute body: () throws -> T) rethrows -> T {
    os_signpost(.begin, log: log, name: name, signpostID: id)
    defer { os_signpost(.end, log: log, name: name, signpostID: id) }
    return try body()
}

#else
// MARK: - Stub Implementations (Linux / non-OSLog platforms)

/// Stub: signpost APIs are no-ops on non-Apple platforms.
@inlinable public func signpostBegin(_ log: Any, name: String, id: UInt64 = 0) {}
@inlinable public func signpostEnd(_ log: Any, name: String, id: UInt64 = 0) {}
@inlinable public func signpostEvent(_ log: Any, name: String) {}

@inlinable
@discardableResult
public func withSignpost<T>(_ log: Any, name: String, id: UInt64 = 0, execute body: () throws -> T) rethrows -> T {
    try body()
}
#endif
