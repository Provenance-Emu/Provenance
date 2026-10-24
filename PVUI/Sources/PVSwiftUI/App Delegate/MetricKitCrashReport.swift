//
//  MetricKitCrashReport.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Pure, SDK-free model of one `MXCrashDiagnostic`, built from its call-stack
//  JSON so the mapping is unit-testable on every platform (MetricKit is
//  `API_UNAVAILABLE(tvos, watchos)`).
//
//  Why this exists: Sentry's crash handler is off (it breaks flycast's SIGSEGV
//  VRAM mapping), and sentry-cocoa builds its MetricKit manager with crash
//  diagnostics disabled. Without forwarding these ourselves, no crash ever
//  reached Sentry — only TestFlight/Organizer and on-device `.ips` files.
//

import Foundation

/// One frame of an `MXCallStackTree`, innermost first.
public struct MetricKitCrashFrame: Equatable, Sendable {
    public let binaryName: String
    public let binaryUUID: String
    public let offset: UInt64

    /// `Binary +0xOFFSET`, the form `atos -l` symbolicates against a dSYM.
    public var line: String { "\(binaryName) +0x\(String(offset, radix: 16))" }

    /// Provenance's own code: the app, its PV* frameworks and the libretro cores.
    public var isAppCode: Bool {
        binaryName.hasPrefix("Provenance") || binaryName.hasPrefix("PV") || binaryName.contains(".libretro")
    }
}

public struct MetricKitCrashReport: Equatable, Sendable {
    /// Frames of the crashed (attributed) thread, innermost first.
    public let frames: [MetricKitCrashFrame]
    public let exceptionType: Int?
    public let exceptionCode: Int?
    public let signal: Int?
    public let terminationReason: String?
    public let build: String?
    /// Why `frames` is empty, when the call-stack JSON could not be read. The
    /// raw JSON still goes out as an attachment.
    public let parseError: String?

    /// How many frames go into the event context; enough to see the caller chain.
    static let contextFrameLimit = 30

    /// - Parameter callStackTreeJSON: `MXCallStackTree.jsonRepresentation()`.
    public init(
        callStackTreeJSON: Data,
        exceptionType: Int?,
        exceptionCode: Int?,
        signal: Int?,
        terminationReason: String?,
        build: String?
    ) {
        switch Self.attributedFrames(in: callStackTreeJSON) {
        case .success(let frames):
            self.frames = frames
            self.parseError = nil
        case .failure(let error):
            self.frames = []
            self.parseError = error.message
        }
        self.exceptionType = exceptionType
        self.exceptionCode = exceptionCode
        self.signal = signal
        self.terminationReason = terminationReason
        self.build = build
    }

    /// `SIGSEGV / EXC_BAD_ACCESS`, falling back to the raw numbers.
    public var exceptionLabel: String {
        let signalName = signal.map { Self.signalNames[$0] ?? "signal \($0)" } ?? "no signal"
        let typeName = exceptionType.map { Self.exceptionTypeNames[$0] ?? "exception \($0)" } ?? "no exception"
        return "\(signalName) / \(typeName)"
    }

    /// The innermost frame in Provenance's own code, else the innermost frame.
    public var culprit: MetricKitCrashFrame? {
        frames.first(where: \.isAppCode) ?? frames.first
    }

    public var title: String {
        "MetricKit crash: \(exceptionLabel) in \(culprit?.binaryName ?? "unknown")"
    }

    /// Groups the same crash together across devices; offsets are stable per build.
    public var fingerprint: [String] {
        ["metrickit-crash", exceptionLabel, culprit?.line ?? (parseError == nil ? "no-frames" : "unparsed-frames")]
    }

    public var sentryTags: [String: String] {
        var tags = ["crash.source": "metrickit", "crash.exception": exceptionLabel]
        if let culprit = culprit { tags["crash.binary"] = culprit.binaryName }
        if let build = build { tags["crash.build"] = build }
        if parseError != nil { tags["crash.frames"] = "unparsed" }
        return tags
    }

    /// Frame lines for the event context, innermost first.
    public var contextFrames: [String] {
        frames.prefix(Self.contextFrameLimit).map(\.line)
    }

    // MARK: - Parsing

    struct ParseError: Error, Equatable {
        let message: String
    }

    /// The attributed thread's frames, or the first thread's when none is marked.
    ///
    /// `jsonRepresentation()` puts `callStacks` at the top level (sentry-cocoa
    /// decodes it that way), but Apple documents it inside a `callStackTree`
    /// object, so both shapes are accepted. A stack-overflow crash nests one
    /// level per frame and can exceed `JSONSerialization`'s depth limit; that
    /// failure is reported rather than passed off as a frameless crash.
    static func attributedFrames(in json: Data) -> Result<[MetricKitCrashFrame], ParseError> {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: json)
        } catch {
            return .failure(ParseError(message: "JSON unreadable: \(error.localizedDescription)"))
        }
        guard let object = parsed as? [String: Any] else {
            return .failure(ParseError(message: "JSON root is not an object"))
        }
        let tree = object["callStackTree"] as? [String: Any] ?? object
        guard let stacks = tree["callStacks"] as? [[String: Any]] else {
            return .failure(ParseError(message: "no callStacks"))
        }
        let stack = stacks.first { $0["threadAttributed"] as? Bool == true } ?? stacks.first
        guard let roots = stack?["callStackRootFrames"] as? [[String: Any]] else {
            return .failure(ParseError(message: "no callStackRootFrames"))
        }
        return .success(flatten(roots))
    }

    /// A root frame is the innermost call; its `subFrames` are its callers.
    /// Iterative, depth-first in document order: MetricKit delivers on a
    /// background queue, and recursing once per frame of a stack-overflow
    /// report could overflow that thread's stack.
    private static func flatten(_ roots: [[String: Any]]) -> [MetricKitCrashFrame] {
        var frames: [MetricKitCrashFrame] = []
        var pending = Array(roots.reversed())
        while let node = pending.popLast() {
            frames.append(MetricKitCrashFrame(
                binaryName: node["binaryName"] as? String ?? "??",
                binaryUUID: node["binaryUUID"] as? String ?? "",
                offset: (node["offsetIntoBinaryTextSegment"] as? NSNumber)?.uint64Value ?? 0
            ))
            if let callers = node["subFrames"] as? [[String: Any]] {
                pending.append(contentsOf: callers.reversed())
            }
        }
        return frames
    }

    private static let signalNames: [Int: String] = [
        4: "SIGILL", 5: "SIGTRAP", 6: "SIGABRT", 8: "SIGFPE", 9: "SIGKILL", 10: "SIGBUS", 11: "SIGSEGV"
    ]

    /// Mach exception numbers from `<mach/exception_types.h>`.
    private static let exceptionTypeNames: [Int: String] = [
        1: "EXC_BAD_ACCESS", 2: "EXC_BAD_INSTRUCTION", 3: "EXC_ARITHMETIC",
        6: "EXC_BREAKPOINT", 10: "EXC_CRASH", 11: "EXC_RESOURCE", 12: "EXC_GUARD"
    ]
}
