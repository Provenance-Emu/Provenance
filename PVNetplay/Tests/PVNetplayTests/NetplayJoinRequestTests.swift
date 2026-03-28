//
//  NetplayJoinRequestTests.swift
//  PVNetplayTests
//
//  Created by Joseph Mattiello on 3/27/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Testing
import Foundation
@testable import PVNetplay

// MARK: - URL parsing tests

@Suite("NetplayJoinRequest URL Parsing Tests")
struct NetplayJoinRequestURLTests {

    @Test("Valid deep link parses host and port")
    func validDeepLink() throws {
        let url = URL(string: "provenance://netplay/join?host=192.168.1.5&port=55435")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.host == "192.168.1.5")
        #expect(request.port == 55435)
        #expect(request.relay == nil)
        #expect(request.gameName == nil)
    }

    @Test("Valid deep link with all optional fields")
    func validDeepLinkAllFields() throws {
        let url = URL(string: "provenance://netplay/join?host=1.2.3.4&port=12345&relay=ra.me&game=Sonic")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.host == "1.2.3.4")
        #expect(request.port == 12345)
        #expect(request.relay == "ra.me")
        #expect(request.gameName == "Sonic")
    }

    @Test("Deep link with game name containing spaces (percent-encoded)")
    func deepLinkWithEncodedGameName() throws {
        let url = URL(string: "provenance://netplay/join?host=10.0.0.1&port=55435&game=Super%20Mario%20World")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.gameName == "Super Mario World")
    }

    @Test("Deep link missing port uses default")
    func missingPortUsesDefault() throws {
        let url = URL(string: "provenance://netplay/join?host=192.168.1.1")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.port == NetplayJoinRequest.defaultPort)
    }

    @Test("Deep link with port=0 uses default")
    func portZeroUsesDefault() throws {
        let url = URL(string: "provenance://netplay/join?host=10.0.0.1&port=0")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.port == NetplayJoinRequest.defaultPort)
    }

    @Test("Deep link with invalid port string uses default")
    func invalidPortStringUsesDefault() throws {
        let url = URL(string: "provenance://netplay/join?host=10.0.0.1&port=notanumber")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.port == NetplayJoinRequest.defaultPort)
    }

    @Test("Deep link missing host returns nil")
    func missingHostReturnsNil() {
        let url = URL(string: "provenance://netplay/join?port=55435")!
        #expect(NetplayJoinRequest.from(url: url) == nil)
    }

    @Test("Deep link with empty host returns nil")
    func emptyHostReturnsNil() {
        let url = URL(string: "provenance://netplay/join?host=&port=55435")!
        #expect(NetplayJoinRequest.from(url: url) == nil)
    }

    @Test("Wrong scheme returns nil")
    func wrongSchemeReturnsNil() {
        let url = URL(string: "https://netplay/join?host=1.2.3.4")!
        #expect(NetplayJoinRequest.from(url: url) == nil)
    }

    @Test("Wrong host component returns nil")
    func wrongHostComponentReturnsNil() {
        let url = URL(string: "provenance://game/join?host=1.2.3.4")!
        #expect(NetplayJoinRequest.from(url: url) == nil)
    }

    @Test("Wrong path returns nil")
    func wrongPathReturnsNil() {
        let url = URL(string: "provenance://netplay/host?host=1.2.3.4")!
        #expect(NetplayJoinRequest.from(url: url) == nil)
    }

    @Test("Max valid port 65535 is accepted")
    func maxPortAccepted() throws {
        let url = URL(string: "provenance://netplay/join?host=10.0.0.1&port=65535")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.port == 65535)
    }

    @Test("Port out of UInt16 range is rejected (uses default)")
    func outOfRangePortUsesDefault() throws {
        // 99999 overflows UInt16 so UInt16("99999") returns nil
        let url = URL(string: "provenance://netplay/join?host=10.0.0.1&port=99999")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.port == NetplayJoinRequest.defaultPort)
    }

    @Test("Minimum valid port 1 is accepted")
    func minPortAccepted() throws {
        let url = URL(string: "provenance://netplay/join?host=10.0.0.1&port=1")!
        let request = try #require(NetplayJoinRequest.from(url: url))
        #expect(request.port == 1)
    }

    @Test("defaultPort is 55435")
    func defaultPortValue() {
        #expect(NetplayJoinRequest.defaultPort == 55435)
    }
}

// MARK: - Notification userInfo parsing tests

@Suite("NetplayJoinRequest Notification Parsing Tests")
struct NetplayJoinRequestNotificationTests {

    @Test("UInt16 port value is parsed correctly")
    func uint16PortParsed() throws {
        let info: [AnyHashable: Any] = ["host": "192.168.1.1", "port": UInt16(12345)]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.port == 12345)
    }

    @Test("String port value is parsed correctly")
    func stringPortParsed() throws {
        let info: [AnyHashable: Any] = ["host": "192.168.1.1", "port": "22222"]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.port == 22222)
    }

    @Test("Int port value is parsed correctly")
    func intPortParsed() throws {
        let info: [AnyHashable: Any] = ["host": "192.168.1.1", "port": 33333]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.port == 33333)
    }

    @Test("Missing port uses default")
    func missingPortUsesDefault() throws {
        let info: [AnyHashable: Any] = ["host": "192.168.1.1"]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.port == NetplayJoinRequest.defaultPort)
    }

    @Test("UInt16(0) port uses default")
    func zeroUInt16PortUsesDefault() throws {
        let info: [AnyHashable: Any] = ["host": "192.168.1.1", "port": UInt16(0)]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.port == NetplayJoinRequest.defaultPort)
    }

    @Test("Missing host returns nil")
    func missingHostReturnsNil() {
        let info: [AnyHashable: Any] = ["port": UInt16(55435)]
        #expect(NetplayJoinRequest.from(notificationUserInfo: info) == nil)
    }

    @Test("Empty host returns nil")
    func emptyHostReturnsNil() {
        let info: [AnyHashable: Any] = ["host": "", "port": UInt16(55435)]
        #expect(NetplayJoinRequest.from(notificationUserInfo: info) == nil)
    }

    @Test("Optional relay and game fields are populated")
    func optionalFieldsPopulated() throws {
        let info: [AnyHashable: Any] = [
            "host": "10.0.0.2",
            "port": UInt16(55435),
            "relay": "ra.me",
            "game": "Chrono Trigger"
        ]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.relay == "ra.me")
        #expect(request.gameName == "Chrono Trigger")
    }

    @Test("Optional relay and game fields default to nil when absent")
    func optionalFieldsNilWhenAbsent() throws {
        let info: [AnyHashable: Any] = ["host": "10.0.0.3", "port": UInt16(55435)]
        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: info))
        #expect(request.relay == nil)
        #expect(request.gameName == nil)
    }

    @Test("AppDelegate-style userInfo roundtrip")
    func appDelegateStyleRoundtrip() throws {
        // Mirrors how PVAppDelegate+Open.swift builds the userInfo dict
        let host = "203.0.113.5"
        let port: UInt16 = 55435
        var userInfo: [String: Any] = ["host": host, "port": port]
        userInfo["relay"] = "ra.me"
        userInfo["game"] = "Street Fighter II"

        let request = try #require(NetplayJoinRequest.from(notificationUserInfo: userInfo))
        #expect(request.host == host)
        #expect(request.port == port)
        #expect(request.relay == "ra.me")
        #expect(request.gameName == "Street Fighter II")
    }
}

// MARK: - Equatable tests

@Suite("NetplayJoinRequest Equatable Tests")
struct NetplayJoinRequestEquatableTests {

    @Test("Two identical requests are equal")
    func equalRequests() {
        let a = NetplayJoinRequest(host: "1.2.3.4", port: 55435, relay: "ra.me", gameName: "Test")
        let b = NetplayJoinRequest(host: "1.2.3.4", port: 55435, relay: "ra.me", gameName: "Test")
        #expect(a == b)
    }

    @Test("Requests with different hosts are not equal")
    func differentHostsNotEqual() {
        let a = NetplayJoinRequest(host: "1.2.3.4", port: 55435)
        let b = NetplayJoinRequest(host: "5.6.7.8", port: 55435)
        #expect(a != b)
    }

    @Test("Requests with different ports are not equal")
    func differentPortsNotEqual() {
        let a = NetplayJoinRequest(host: "1.2.3.4", port: 55435)
        let b = NetplayJoinRequest(host: "1.2.3.4", port: 12345)
        #expect(a != b)
    }

    @Test("Relay nil vs non-nil are not equal")
    func relayNilVsNonNilNotEqual() {
        let a = NetplayJoinRequest(host: "1.2.3.4", port: 55435, relay: nil)
        let b = NetplayJoinRequest(host: "1.2.3.4", port: 55435, relay: "ra.me")
        #expect(a != b)
    }

    @Test("Requests with different game names are not equal")
    func differentGameNamesNotEqual() {
        let a = NetplayJoinRequest(host: "1.2.3.4", port: 55435, gameName: "Sonic")
        let b = NetplayJoinRequest(host: "1.2.3.4", port: 55435, gameName: "Mario")
        #expect(a != b)
    }

    @Test("gameName nil vs non-nil are not equal")
    func gameNameNilVsNonNilNotEqual() {
        let a = NetplayJoinRequest(host: "1.2.3.4", port: 55435, gameName: nil)
        let b = NetplayJoinRequest(host: "1.2.3.4", port: 55435, gameName: "Sonic")
        #expect(a != b)
    }
}
