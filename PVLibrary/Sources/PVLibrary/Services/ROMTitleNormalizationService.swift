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
    public func buildProposals() async -> [ROMTitleRenameProposal] {
        do {
            return try await RealmContext.withBackgroundRealm { realm -> [ROMTitleRenameProposal] in
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
        } catch {
            ELOG("ROMTitleNormalizationService: failed to build proposals: \(error)")
            return []
        }
    }

    // MARK: - Apply

    /// Writes the proposed titles back to Realm for the supplied proposals.
    ///
    /// - Parameter proposals: Proposals to apply.  Each `id` is used to look up
    ///   the live Realm object.  Proposals for games no longer in the database are
    ///   silently skipped.
    public func applyProposals(_ proposals: [ROMTitleRenameProposal]) async throws {
        guard !proposals.isEmpty else { return }

        let idToTitle: [String: String] = Dictionary(
            proposals.map { ($0.id, $0.proposedTitle) },
            uniquingKeysWith: { _, last in last }
        )

        var appliedCount = 0
        try await RealmContext.withBackgroundRealm { realm in
            try realm.write {
                for (id, proposedTitle) in idToTitle {
                    guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: id) else {
                        WLOG("ROMTitleNormalizationService: game id '\(id)' not found, skipping")
                        continue
                    }
                    DLOG("Normalized title: '\(game.title)' → '\(proposedTitle)'")
                    game.title = proposedTitle
                    appliedCount += 1
                }
            }
        }
        ILOG("ROMTitleNormalizationService: applied \(appliedCount)/\(proposals.count) title rename(s)")
    }

    /// Convenience: build proposals and apply all of them in one call.
    @discardableResult
    public func normalizeAll() async throws -> Int {
        let proposals = await buildProposals()
        try await applyProposals(proposals)
        return proposals.count
    }
}
