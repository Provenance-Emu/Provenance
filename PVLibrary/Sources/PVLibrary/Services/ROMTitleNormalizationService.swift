//
//  ROMTitleNormalizationService.swift
//  PVLibrary
//
//  Service for normalizing ROM titles in the game library.
//  Supports preview (diff) and bulk application without per-item confirmation.
//

import Foundation
import PVPrimitives
import PVRealm
import PVLogging
import RealmSwift

// MARK: - Rename Proposal

/// A proposed title rename for a single library game entry.
public struct ROMTitleRenameProposal: Identifiable, Sendable {
    public let id: String
    public let currentTitle: String
    public let proposedTitle: String
}

// MARK: - Service

/// Normalizes game titles in the Realm library by stripping ROM annotation tags
/// (e.g. `(USA)`, `[!]`, disc numbers).
///
/// ```swift
/// let svc = ROMTitleNormalizationService()
/// let proposals = await svc.buildProposals()   // preview what changes
/// try await svc.applyProposals(proposals)       // apply all (or a subset)
/// ```
public final class ROMTitleNormalizationService: Sendable {

    public init() {}

    // MARK: - Preview

    /// Returns proposals for every game whose title would change after normalization.
    /// Only entries with a meaningful diff are included.
    /// - Throws: Any Realm error encountered during the scan, so callers can
    ///   display an explicit failure state rather than treating it as "no proposals".
    public func buildProposals() async throws -> [ROMTitleRenameProposal] {
        try await RealmContext.withBackgroundRealm { realm -> [ROMTitleRenameProposal] in
            let games = realm.objects(PVGame.self)
            var proposals: [ROMTitleRenameProposal] = []
            for game in games {
                let proposed = game.title.normalizedROMTitle()
                guard proposed != game.title else { continue }
                proposals.append(ROMTitleRenameProposal(
                    id: game.md5Hash,
                    currentTitle: game.title,
                    proposedTitle: proposed
                ))
            }
            return proposals
        }
    }

    // MARK: - Apply

    /// Writes the proposed titles back to Realm for the supplied proposals.
    ///
    /// - Parameter proposals: Proposals to apply.  Each `id` is used to look up
    ///   the live Realm object.  Proposals for games no longer in the database are
    ///   silently skipped.
    /// - Returns: The number of titles actually updated (may be less than `proposals.count`
    ///   if some games were deleted between preview and apply).
    @discardableResult
    public func applyProposals(_ proposals: [ROMTitleRenameProposal]) async throws -> Int {
        guard !proposals.isEmpty else { return 0 }

        let idToTitle: [String: String] = Dictionary(
            proposals.map { ($0.id, $0.proposedTitle) },
            uniquingKeysWith: { _, last in last }
        )

        // Return the count from inside the background task to avoid capturing and
        // mutating a var across a Task.detached boundary (Swift 6 concurrency).
        let appliedCount = try await RealmContext.withBackgroundRealm { realm -> Int in
            var count = 0
            try realm.write {
                for (id, proposedTitle) in idToTitle {
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: id) else {
                        WLOG("ROMTitleNormalizationService: game id '\(id)' not found, skipping")
                        continue
                    }
                    DLOG("Normalized title: '\(game.title)' → '\(proposedTitle)'")
                    game.title = proposedTitle
                    count += 1
                }
            }
            return count
        }
        ILOG("ROMTitleNormalizationService: applied \(appliedCount)/\(idToTitle.count) title rename(s)")
        return appliedCount
    }

    /// Convenience: build proposals and apply all of them in one call.
    @discardableResult
    public func normalizeAll() async throws -> Int {
        let proposals = try await buildProposals()
        return try await applyProposals(proposals)
    }
}
