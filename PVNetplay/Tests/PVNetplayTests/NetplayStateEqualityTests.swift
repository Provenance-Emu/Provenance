//
//  NetplayStateEqualityTests.swift
//  PVNetplayTests
//

import Foundation
import Testing
@testable import PVNetplay

@Suite("NetplayState equality")
struct NetplayStateEqualityTests {
    private func room(id: UUID, players: Int, spectators: Int = 0) -> NetplayRoom {
        NetplayRoom(id: id, hostName: "Host", gameName: "", gameHash: "", coreIdentifier: "com.provenance.core.mGBA",
                    maxPlayers: 2, currentPlayers: players, isLAN: true, hostAddress: "192.168.1.2", port: 55435,
                    spectatorCount: spectators)
    }

    /// mGBA and PPSSPP publish their polled state only when it differs from the last one.
    @Test func aPlayerJoiningTheHostedRoomIsAChange() {
        let id = UUID()
        #expect(NetplayState.hosting(room: room(id: id, players: 1)) != .hosting(room: room(id: id, players: 2)))
        #expect(NetplayState.hosting(room: room(id: id, players: 1)) != .hosting(room: room(id: id, players: 1, spectators: 1)))
    }

    @Test func theSameRoomAndOccupancyIsNotAChange() {
        let id = UUID()
        #expect(NetplayState.hosting(room: room(id: id, players: 2)) == .hosting(room: room(id: id, players: 2)))
    }

    @Test func differentRoomsDiffer() {
        #expect(NetplayState.hosting(room: room(id: UUID(), players: 1)) != .hosting(room: room(id: UUID(), players: 1)))
    }
}
