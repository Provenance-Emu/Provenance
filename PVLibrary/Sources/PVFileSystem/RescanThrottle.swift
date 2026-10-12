//
//  RescanThrottle.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Rate limit for library rescans triggered by foregrounding or iCloud metadata updates (D17).
//

import Foundation

public struct RescanThrottle: Sendable {
    public static let defaultInterval: TimeInterval = 60

    private let interval: TimeInterval
    private var last: Date?

    public init(interval: TimeInterval = RescanThrottle.defaultInterval) {
        self.interval = interval
    }

    /// `true` at most once per `interval`.
    public mutating func shouldFire(now: Date = Date()) -> Bool {
        if let last, now.timeIntervalSince(last) < interval { return false }
        last = now
        return true
    }

    /// How long until `shouldFire` would next succeed: `0` when it would now (or never fired).
    public func remainingInterval(now: Date = Date()) -> TimeInterval {
        guard let last else { return 0 }
        return max(0, interval - now.timeIntervalSince(last))
    }
}
