//
//  PatchDatabaseRateLimiter.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Simple actor rate limiter + TTL response cache for online patch queries.
public actor PatchDatabaseRateLimiter {
    private let minimumInterval: TimeInterval
    private let cacheTTL: TimeInterval
    private var lastRequestAt: Date?
    private var cache: [String: (expires: Date, data: Data)] = [:]

    public init(minimumInterval: TimeInterval = 1.0, cacheTTL: TimeInterval = 60 * 15) {
        self.minimumInterval = minimumInterval
        self.cacheTTL = cacheTTL
    }

    public func cachedData(for key: String) -> Data? {
        guard let entry = cache[key] else { return nil }
        if entry.expires < Date() {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    public func store(_ data: Data, for key: String) {
        cache[key] = (Date().addingTimeInterval(cacheTTL), data)
    }

    public func waitIfNeeded() async {
        if let last = lastRequestAt {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minimumInterval {
                let delay = minimumInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        lastRequestAt = Date()
    }
}
