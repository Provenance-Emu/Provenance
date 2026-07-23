//
//  SentryEventFilter+Sentry.swift
//  PVSwiftUI
//
//  Maps `Sentry.Event` payloads into `SentryEventSnapshot` for `SentryEventFilter`.
//

import Foundation

#if canImport(Sentry)
import Sentry

extension SentryEventSnapshot {
    /// Builds a testable snapshot from a Sentry event inside `beforeSend`.
    static func fromSentryEvent(_ event: Event) -> SentryEventSnapshot {
        let exception = event.exceptions?.first
        let mechanismType = exception?.mechanism?.type
        let frames: [SentryEventFrame] = (exception?.stacktrace?.frames ?? []).map { frame in
            SentryEventFrame(
                function: frame.function,
                filename: frame.fileName,
                package: frame.package,
                inApp: frame.inApp?.boolValue ?? false
            )
        }

        var tags: [String: String] = [:]
        if let eventTags = event.tags {
            for (key, value) in eventTags {
                tags[key] = value
            }
        }

        return SentryEventSnapshot(
            mechanismType: mechanismType,
            exceptionValue: exception?.value,
            exceptionType: exception?.type,
            level: levelString(event.level),
            transaction: event.transaction,
            requestURL: event.request?.url,
            title: nil,
            tags: tags,
            frames: frames
        )
    }

    /// Maps `SentryLevel` (a `UInt`-backed ObjC enum) to the sentry.io string
    /// convention that `SentryEventFilter` matches against (e.g. `"info"`).
    private static func levelString(_ level: SentryLevel) -> String {
        switch level {
        case .none: return "none"
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        case .fatal: return "fatal"
        @unknown default: return "unknown"
        }
    }
}
#endif
