//
//  PVFeatureFlagsFetcher.swift
//  PVFeatureFlags
//
//  Created by Claude on 2/28/26.
//  Copyright 2025 Joseph Mattiello. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors that can occur during remote feature flags fetching
public enum PVFeatureFlagsFetcherError: Error, LocalizedError {
    case notConfigured
    case networkError(Error)
    case decodingError(Error)
    case maxRetriesExceeded(lastError: Error)
    case badHTTPStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Remote URL not configured"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode feature flags: \(error.localizedDescription)"
        case .maxRetriesExceeded(let error):
            return "Max retries exceeded. Last error: \(error.localizedDescription)"
        case .badHTTPStatus(let code):
            return "HTTP error \(code)"
        }
    }
}

/// Handles remote fetching of feature flags configuration with retry logic and disk caching.
public struct PVFeatureFlagsFetcher: Sendable {
    /// The remote URL to fetch configuration from
    public let url: URL
    /// Maximum number of retry attempts on failure (0 means no retries)
    public let maxRetries: Int
    /// Base delay in seconds for exponential backoff between retries
    public let retryBaseDelay: TimeInterval
    /// How long a cached configuration remains valid (in seconds)
    public let cacheDuration: TimeInterval

    /// UserDefaults key for cached configuration data (unique per remote URL).
    private var cacheDataKey: String {
        "PVFeatureFlagsRemoteConfig_\(url.absoluteString)"
    }

    /// UserDefaults key for cache timestamp (unique per remote URL).
    private var cacheTimestampKey: String {
        "PVFeatureFlagsRemoteConfigTimestamp_\(url.absoluteString)"
    }

    /// Initialize a new fetcher.
    /// - Parameters:
    ///   - url: Remote URL for the features JSON
    ///   - maxRetries: Maximum retry attempts (default: 3)
    ///   - retryBaseDelay: Base delay for exponential backoff in seconds (default: 1.0)
    ///   - cacheDuration: Cache validity duration in seconds (default: 3600 = 1 hour)
    public init(
        url: URL,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1.0,
        cacheDuration: TimeInterval = 3600
    ) {
        self.url = url
        self.maxRetries = max(0, maxRetries)
        self.retryBaseDelay = max(0, retryBaseDelay)
        self.cacheDuration = max(0, cacheDuration)
    }

    /// Fetches the configuration with exponential backoff retry logic.
    /// On success, saves the result to the local cache.
    /// - Returns: Parsed `FeatureFlagsConfiguration`
    /// - Throws: `PVFeatureFlagsFetcherError` if all retries are exhausted
    public func fetchWithRetry() async throws -> FeatureFlagsConfiguration {
        var lastError: Error = PVFeatureFlagsFetcherError.networkError(
            NSError(domain: "PVFeatureFlags", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        )

        for attempt in 0...maxRetries {
            do {
                let config = try await fetchOnce()
                saveToCache(config)
                return config
            } catch {
                lastError = error

                if attempt < maxRetries {
                    // Exponential backoff: delay = baseDelay * 2^attempt, clamped to prevent overflow when converting to nanoseconds
                    let delay = retryBaseDelay * pow(2.0, Double(attempt))
                    let maxDelaySeconds = Double(UInt64.max) / 1_000_000_000.0
                    let safeDelay = delay.isFinite && delay > 0 ? min(delay, maxDelaySeconds) : 0
                    try await Task.sleep(nanoseconds: UInt64(safeDelay * 1_000_000_000))
                }
            }
        }

        throw PVFeatureFlagsFetcherError.maxRetriesExceeded(lastError: lastError)
    }

    /// Performs a single HTTP fetch without retry.
    private func fetchOnce() async throws -> FeatureFlagsConfiguration {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw PVFeatureFlagsFetcherError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw PVFeatureFlagsFetcherError.badHTTPStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        } catch {
            throw PVFeatureFlagsFetcherError.decodingError(error)
        }
    }

    /// Loads a previously cached configuration if one exists.
    /// - Returns: Cached `FeatureFlagsConfiguration`, or `nil` if no cache is available.
    public func loadCached() -> FeatureFlagsConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: cacheDataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
    }

    /// Returns `true` if a cached configuration exists, decodes successfully, and has not yet expired.
    public func isCacheValid() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return false
        }
        guard let data = UserDefaults.standard.data(forKey: cacheDataKey) else {
            clearCache()
            return false
        }
        guard (try? JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)) != nil else {
            clearCache()
            return false
        }
        return Date().timeIntervalSince(timestamp) < cacheDuration
    }

    /// Persists a configuration to the local cache along with the current timestamp.
    public func saveToCache(_ config: FeatureFlagsConfiguration) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: cacheDataKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
    }

    /// Removes the cached configuration and its timestamp.
    public func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheDataKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
}
