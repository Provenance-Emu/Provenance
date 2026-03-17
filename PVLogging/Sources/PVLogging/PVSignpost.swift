//
//  PVSignpost.swift
//  PVLogging
//
//  Created by Joseph Mattiello on 2025.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//
//  Lightweight wrappers around `os.signpost` for profiling performance-critical
//  sections such as frame timing and audio processing. On non-Apple platforms
//  all functions are no-ops that compile away entirely.
//

#if canImport(OSLog)
import OSLog

/// A set of pre-configured OSLog instances used exclusively for signpost intervals.
/// Each instance corresponds to a performance domain visible in Instruments.
public enum PVSignpostLog {
    /// Frame render timing (emulator display loop).
    public static let frame = OSLog(subsystem: os.Logger.provenanceSubsystem, category: "frame")

    /// Audio callback timing (core audio processing).
    public static let audio = OSLog(subsystem: os.Logger.provenanceSubsystem, category: "audio")

    /// ROM load / library scan timing.
    public static let library = OSLog(subsystem: os.Logger.provenanceSubsystem, category: "library")
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

/// Cross-platform stand-in for `OSSignpostID` on non-Apple platforms.
/// Using the same type name keeps call sites free of `#if canImport(OSLog)` guards.
public typealias OSSignpostID = UInt64
public extension OSSignpostID {
    /// Matches the `.exclusive` sentinel used in the OSLog implementation.
    static let exclusive: OSSignpostID = 0
}

/// Stub `PVSignpostLog` for non-OSLog platforms so call sites remain guard-free.
public enum PVSignpostLog {
    /// Frame render timing (emulator display loop) – placeholder on non-Apple platforms.
    public static let frame: Any = ()

    /// Audio callback timing (core audio processing) – placeholder on non-Apple platforms.
    public static let audio: Any = ()

    /// ROM load / library scan timing – placeholder on non-Apple platforms.
    public static let library: Any = ()
}

/// Stub: signpost APIs are no-ops on non-Apple platforms.
@inlinable public func signpostBegin(_ log: Any, name: StaticString, id: OSSignpostID = .exclusive) {}
@inlinable public func signpostEnd(_ log: Any, name: StaticString, id: OSSignpostID = .exclusive) {}
@inlinable public func signpostEvent(_ log: Any, name: StaticString) {}

@inlinable
@discardableResult
public func withSignpost<T>(_ log: Any, name: StaticString, id: OSSignpostID = .exclusive, execute body: () throws -> T) rethrows -> T {
    try body()
}
#endif
