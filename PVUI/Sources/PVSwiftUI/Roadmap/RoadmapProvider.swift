//
//  RoadmapProvider.swift
//  PVUI
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Loads the bundled roadmap.json, then enriches it with live GitHub issue
//  open/closed state in the background.  Closed issues are automatically
//  promoted to `.complete`.  Results are cached for 6 hours.
//

import Foundation
import SwiftUI
#if canImport(PVLogging)
import PVLogging
#endif

// MARK: - RoadmapProvider

@MainActor
public final class RoadmapProvider: ObservableObject {

    @Published public private(set) var epics: [RoadmapEpic] = []
    @Published public private(set) var isRefreshing = false

    // 6-hour TTL for the GitHub state cache
    private static let cacheTTL: TimeInterval = 6 * 60 * 60
    private static let cacheKey = "PVRoadmap_githubStates"
    private static let cacheTimestampKey = "PVRoadmap_githubStatesTimestamp"

    public init() {
        // Start with bundled data immediately
        epics = RoadmapLoader.loadAll()
    }

    // MARK: - Public API

    /// Refresh GitHub issue states in the background and merge into `epics`.
    public func refreshIfNeeded() {
        Task { await refresh(force: false) }
    }

    public func forceRefresh() {
        Task { await refresh(force: true) }
    }

    // MARK: - Private

    private func refresh(force: Bool) async {
        // Apply any already-cached states first so the UI updates immediately
        applyCachedStates()

        guard force || isCacheStale() else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        let issueNumbers = epics.compactMap(\.githubIssue)
        guard !issueNumbers.isEmpty else { return }

        // Fetch all issue states concurrently
        let states = await fetchIssueStates(for: issueNumbers)
        guard !states.isEmpty else { return }

        // Persist and apply
        saveStatesToCache(states)
        applyStates(states)
    }

    private func applyCachedStates() {
        guard let cached = loadCachedStates() else { return }
        applyStates(cached)
    }

    private func applyStates(_ states: [Int: Bool]) {
        epics = epics.map { epic in
            guard let issueNumber = epic.githubIssue,
                  let isClosed = states[issueNumber] else { return epic }
            // Only auto-promote active/planned → complete when the issue is closed.
            // Never demote an already-complete epic.
            if isClosed && epic.status != .complete {
                return epic.withStatus(.complete)
            }
            return epic
        }
    }

    // MARK: - GitHub REST API

    private func fetchIssueStates(for numbers: [Int]) async -> [Int: Bool] {
        var result: [Int: Bool] = [:]
        await withTaskGroup(of: (Int, Bool)?.self) { group in
            for number in numbers {
                group.addTask {
                    await self.fetchSingleIssueState(number: number)
                }
            }
            for await pair in group {
                if let (num, closed) = pair {
                    result[num] = closed
                }
            }
        }
        return result
    }

    private func fetchSingleIssueState(number: Int) async -> (Int, Bool)? {
        let urlString = "https://api.github.com/repos/Provenance-Emu/Provenance/issues/\(number)"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let state = json["state"] as? String else { return nil }
            return (number, state == "closed")
        } catch {
            return nil
        }
    }

    // MARK: - Cache (UserDefaults)

    private func isCacheStale() -> Bool {
        guard let ts = UserDefaults.standard.object(forKey: Self.cacheTimestampKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(ts) > Self.cacheTTL
    }

    private func loadCachedStates() -> [Int: Bool]? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let raw = try? JSONDecoder().decode([String: Bool].self, from: data) else { return nil }
        // Keys are stored as strings because JSON keys must be strings
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
            Int(k).map { ($0, v) }
        })
    }

    private func saveStatesToCache(_ states: [Int: Bool]) {
        let stringKeyed = Dictionary(uniqueKeysWithValues: states.map { ("\($0.key)", $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
            UserDefaults.standard.set(Date(), forKey: Self.cacheTimestampKey)
        }
    }
}
