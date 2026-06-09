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
                filename: frame.filename,
                package: frame.package,
                inApp: frame.inApp
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
            level: event.level.rawValue,
            transaction: event.transaction,
            requestURL: event.request?.url,
            title: nil,
            tags: tags,
            frames: frames
        )
    }
}
#endif
