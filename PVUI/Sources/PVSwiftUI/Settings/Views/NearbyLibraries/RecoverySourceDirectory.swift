//
//  RecoverySourceDirectory.swift
//  PVSwiftUI
//
//  The libraries a missing game may be copied back from, found without any UI on screen.
//

import Foundation
import PVLibrarySharing
import PVSystems
import UIKit

/// Builds the source for a discovered peer. Shared by the browse screens and recovery.
@MainActor
enum LibrarySourceFactory {
    /// This device's sharing identity. The name tells the other owner which app is asking.
    static func identity() -> PeerIdentity {
        KeychainPeerIdentityStore().loadOrCreate(name: "Provenance on \(UIDevice.current.name)")
    }

    /// The source for an iFly, iCube or Provenance peer. Content servers need a login and
    /// are built by `contentServerSource`.
    static func peerSource(for peer: DiscoveredPeer, identity: PeerIdentity, systems: Set<SystemIdentifier>) -> any LibrarySource {
        switch peer.app {
        case .iFly:
            return IFlyContinuitySource(baseURLs: peer.baseURLs, identity: identity)
        case .iCube:
            return ICubeContinuitySource(baseURLs: peer.baseURLs, identity: identity, expectedPeerID: peer.advertisement.peerId)
        case .pvLibrary, .contentServer:
            // Ask only for what this device plays; the source filters locally too.
            return PVLibrarySource(baseURLs: peer.baseURLs, identity: identity, systems: systems)
        }
    }

    /// A content server signed in with its saved token only: no password, so no prompt.
    static func contentServerSource(
        for server: NearbyLibrariesModel.ContentServer, identity: PeerIdentity, systems: Set<SystemIdentifier>
    ) -> ECSSource {
        ECSSource(
            server: server.url, username: server.username, password: nil,
            deviceName: identity.name, systems: systems, tokens: KeychainECSTokenStore()
        )
    }
}

/// One library recovery may ask.
struct RecoverySource: Sendable {
    let source: any LibrarySource
    /// Shown in the prompt and the final alert.
    let name: String
    /// The peer's id or the server's URL; stored in the game's source hint.
    let identity: String
    /// Keeps this source's staging folders apart (`LibraryPuller.peerKey`).
    let peerKey: String
    /// 1 nearby device, 2 server. Lower is asked first.
    let rank: Int
}

struct RecoverySourceList: Sendable {
    var sources: [RecoverySource] = []
    /// Saved sources that cannot answer without the user signing in again.
    var needsSignIn: [String] = []
    /// Local Network access is off, so no nearby device could be seen.
    var localNetworkDenied = false
}

/// Finds recovery sources on demand. Nothing here runs unless a game's file is missing.
@MainActor
final class RecoverySourceDirectory {
    /// How long to listen for nearby devices before asking the ones that answered.
    static let discoveryWindow: Duration = .seconds(3)
    static let nearbyRank = 1
    static let serverRank = 2

    /// Peers whose library this device has opened before. Asking an iFly or Provenance peer
    /// for its catalogue can put an approval prompt on that device, so recovery only asks
    /// peers that already said yes once.
    private static let knownPeersKey = "LibrarySharing.recovery.knownPeers"

    static func noteCatalogueLoaded(from peer: DiscoveredPeer) {
        guard peer.app != .contentServer else { return }
        var known = Set(UserDefaults.standard.stringArray(forKey: knownPeersKey) ?? [])
        guard known.insert(peer.id).inserted else { return }
        UserDefaults.standard.set(Array(known).sorted(), forKey: knownPeersKey)
    }

    private var loadedIdentity: PeerIdentity?
    private var identity: PeerIdentity {
        if let loadedIdentity { return loadedIdentity }
        let created = LibrarySourceFactory.identity()
        loadedIdentity = created
        return created
    }

    /// Paired nearby devices that answer within the discovery window, then saved servers.
    func sources(for system: SystemIdentifier) async -> RecoverySourceList {
        var list = RecoverySourceList()
        let identity = identity
        let systems: Set<SystemIdentifier> = [system]

        let snapshot = await discover()
        list.localNetworkDenied = snapshot.localNetworkDenied
        let known = Set(UserDefaults.standard.stringArray(forKey: Self.knownPeersKey) ?? [])
        for peer in snapshot.peers where peer.isVisible(ownPeerId: identity.id, playable: systems) {
            guard await isPaired(peer, known: known) else { continue }
            list.sources.append(RecoverySource(
                source: LibrarySourceFactory.peerSource(for: peer, identity: identity, systems: systems),
                name: peer.serviceName, identity: peer.id, peerKey: peer.id, rank: Self.nearbyRank
            ))
        }

        let tokens = KeychainECSTokenStore()
        for server in savedContentServers() {
            let name = server.url.host ?? "Content Server"
            guard tokens.token(for: server.url) != nil else {
                list.needsSignIn.append(name)
                continue
            }
            let identityString = server.url.absoluteString
            list.sources.append(RecoverySource(
                source: LibrarySourceFactory.contentServerSource(for: server, identity: identity, systems: systems),
                name: name, identity: identityString, peerKey: PeerApp.contentServer.rawValue + ":" + identityString,
                rank: Self.serverRank
            ))
        }
        return list
    }

    private func isPaired(_ peer: DiscoveredPeer, known: Set<String>) async -> Bool {
        switch peer.app {
        case .iCube:
            // Pairing with iCube records the host's key; without it a copy can't be bound to it.
            guard let peerID = peer.advertisement.peerId else { return false }
            return await LibrarySharingService.shared.trust.peer(withId: peerID) != nil
        case .iFly, .pvLibrary:
            return known.contains(peer.id)
        case .contentServer:
            return false
        }
    }

    private func savedContentServers() -> [NearbyLibrariesModel.ContentServer] {
        guard let data = UserDefaults.standard.data(forKey: NearbyLibrariesModel.contentServersKey) else { return [] }
        return (try? JSONDecoder().decode([NearbyLibrariesModel.ContentServer].self, from: data)) ?? []
    }

    /// Listens for adverts for one discovery window and returns the last snapshot.
    private func discover() async -> PeerBrowserSnapshot {
        let browser = PeerBrowser()
        let latest = LatestSnapshot()
        // Cancelling the loop ends the stream, which stops the browser.
        let listening = Task { @MainActor in
            for await snapshot in browser.snapshots() { latest.value = snapshot }
        }
        try? await Task.sleep(for: Self.discoveryWindow)
        listening.cancel()
        browser.stop()
        return latest.value
    }
}

@MainActor
private final class LatestSnapshot {
    var value = PeerBrowserSnapshot()
}
