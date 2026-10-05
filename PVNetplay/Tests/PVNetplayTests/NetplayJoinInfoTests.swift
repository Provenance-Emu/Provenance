//
//  NetplayJoinInfoTests.swift
//  PVNetplayTests
//

import Foundation
import Testing
@testable import PVNetplay

@Suite("NetplayJoinInfo")
struct NetplayJoinInfoTests {

    @Test("Round-trips through its encoding")
    func roundTrip() throws {
        let info = NetplayJoinInfo(port: 55435, addresses: ["192.168.1.20", "2001:db8::1"])
        #expect(NetplayJoinInfo.decode(try info.encoded()) == info)
    }

    @Test("A message from an incompatible version isn't decoded")
    func rejectsOtherVersions() throws {
        var info = NetplayJoinInfo(port: 1, addresses: [])
        info.version = NetplayJoinInfo.currentVersion + 1
        #expect(NetplayJoinInfo.decode(try info.encoded()) == nil)
    }

    @Test("The old two-byte port message isn't mistaken for one")
    func rejectsLegacyPortMessage() {
        #expect(NetplayJoinInfo.decode(Data([0xD8, 0x8B])) == nil)
    }

    @Test("Local addresses exclude loopback and link-local")
    func localAddresses() {
        for address in NetplayLocalAddresses.current() {
            #expect(address != "127.0.0.1")
            #expect(address != "::1")
            #expect(!address.hasPrefix("169.254."))
            #expect(!address.lowercased().hasPrefix("fe80"))
        }
    }
}
