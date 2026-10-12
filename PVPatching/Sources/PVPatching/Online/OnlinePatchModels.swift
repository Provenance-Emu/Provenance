//
//  OnlinePatchModels.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Category of an online patch listing.
public enum OnlinePatchCategory: String, Sendable, Codable, CaseIterable, Identifiable, Hashable {
    case translation
    case hack
    case improvement
    case bugfix
    case patch
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .translation: return "Translation"
        case .hack: return "Hack"
        case .improvement: return "Improvement"
        case .bugfix: return "Bug Fix"
        case .patch: return "Patch"
        case .unknown: return "Other"
        }
    }

    /// Path segment used on RomHacking.net entry URLs.
    public var romHackingPathComponent: String? {
        switch self {
        case .translation: return "translations"
        case .hack: return "hacks"
        case .improvement: return "improvements"
        case .bugfix: return "bugfixes"
        case .patch: return "patches"
        case .unknown: return nil
        }
    }

    public static func infer(fromPath path: String) -> OnlinePatchCategory {
        let lower = path.lowercased()
        if lower.contains("/translations/") { return .translation }
        if lower.contains("/hacks/") { return .hack }
        if lower.contains("/improvements/") { return .improvement }
        if lower.contains("/bugfixes/") || lower.contains("/bugfix/") { return .bugfix }
        if lower.contains("/patches/") { return .patch }
        return .unknown
    }
}

/// Lightweight search hit from an online patch database.
public struct OnlinePatchSearchResult: Sendable, Identifiable, Hashable, Codable {
    public var id: String
    public var title: String
    public var author: String?
    public var category: OnlinePatchCategory
    public var platformName: String?
    public var snippet: String?
    public var pageURL: URL
    public var rating: Double?

    public init(
        id: String,
        title: String,
        author: String? = nil,
        category: OnlinePatchCategory,
        platformName: String? = nil,
        snippet: String? = nil,
        pageURL: URL,
        rating: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.category = category
        self.platformName = platformName
        self.snippet = snippet
        self.pageURL = pageURL
        self.rating = rating
    }
}

/// Full detail for an online patch listing.
public struct OnlinePatchInfo: Sendable, Identifiable, Hashable, Codable {
    public var id: String
    public var title: String
    public var author: String?
    public var version: String?
    public var category: OnlinePatchCategory
    public var platformName: String?
    public var language: String?
    public var patchDescription: String?
    public var pageURL: URL
    public var downloadURL: URL?
    public var releaseDateDescription: String?
    public var screenshotURLs: [URL]
    public var rating: Double?

    public init(
        id: String,
        title: String,
        author: String? = nil,
        version: String? = nil,
        category: OnlinePatchCategory,
        platformName: String? = nil,
        language: String? = nil,
        patchDescription: String? = nil,
        pageURL: URL,
        downloadURL: URL? = nil,
        releaseDateDescription: String? = nil,
        screenshotURLs: [URL] = [],
        rating: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.version = version
        self.category = category
        self.platformName = platformName
        self.language = language
        self.patchDescription = patchDescription
        self.pageURL = pageURL
        self.downloadURL = downloadURL
        self.releaseDateDescription = releaseDateDescription
        self.screenshotURLs = screenshotURLs
        self.rating = rating
    }

    public var asMetadata: PatchMetadata {
        PatchMetadata(
            title: title,
            author: author,
            version: version,
            description: patchDescription,
            sourceURL: pageURL,
            categories: [category.rawValue]
        )
    }
}

/// Filters applied to an online patch search.
public struct OnlinePatchSearchFilter: Sendable, Hashable, Codable {
    public var category: OnlinePatchCategory?
    public var platformQuery: String?
    public var author: String?

    public init(
        category: OnlinePatchCategory? = nil,
        platformQuery: String? = nil,
        author: String? = nil
    ) {
        self.category = category
        self.platformQuery = platformQuery
        self.author = author
    }

    public static let empty = OnlinePatchSearchFilter()
}

/// Progress for an online patch download.
public struct OnlinePatchDownloadProgress: Sendable, Equatable {
    public var fractionCompleted: Double
    public var status: String

    public init(fractionCompleted: Double, status: String = "") {
        self.fractionCompleted = fractionCompleted
        self.status = status
    }
}

/// Errors from online patch databases.
public enum OnlinePatchDatabaseError: Error, LocalizedError, Sendable, Equatable {
    case notOptedIn
    case invalidQuery
    case network(String)
    case blockedByUpstream
    /// The search index (DuckDuckGo HTML) returned a bot challenge instead of results.
    case searchBlocked
    case notFound
    case parseFailed(String)
    case downloadFailed(String)
    case unsupportedURL

    public var errorDescription: String? {
        switch self {
        case .notOptedIn:
            return "Online patch search is disabled. Enable it in Settings to continue."
        case .invalidQuery:
            return "Enter a search query."
        case .network(let message):
            return "Network error: \(message)"
        case .blockedByUpstream:
            return "RomHacking.net blocked the in-app request. Open the page in Safari instead."
        case .searchBlocked:
            return "The search index is rate-limiting this device. Wait a minute and retry, or open the search in Safari."
        case .notFound:
            return "No patch listing found."
        case .parseFailed(let message):
            return "Could not parse results: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .unsupportedURL:
            return "That URL is not a supported RomHacking.net patch page."
        }
    }
}
