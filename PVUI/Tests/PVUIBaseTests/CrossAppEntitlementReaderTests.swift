//
//  CrossAppEntitlementReaderTests.swift
//  PVUIBaseTests
//
//  Decode + policy tests for the `ifly.pro` side of the cross-app entitlement
//  bridge. Only the pure half is exercised — `grantsPlus(rawValue:now:)` takes
//  the raw keychain string and an injected clock, so no keychain, no
//  FreemiumKit, and no StoreKit are involved.
//

import Testing
import Foundation
@testable import PVUIBase

@Suite("Cross-App Entitlement Reader")
struct CrossAppEntitlementReaderTests {

    /// Fixed clock so the grace-window boundaries are deterministic.
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let grace = CrossAppEntitlementReader.renewalGrace

    /// Build a v1 mirror payload the way both apps write it: JSON with dates
    /// as unix seconds, `expiresAt` omitted entirely for lifetime.
    private static func v1JSON(status: String,
                               period: String? = "yearly",
                               expiresAt: Date?,
                               v: Int = 1,
                               includeUpdatedAt: Bool = true) -> String {
        var object: [String: Any] = ["v": v, "status": status]
        if let period { object["period"] = period }
        if let expiresAt { object["expiresAt"] = expiresAt.timeIntervalSince1970 }
        if includeUpdatedAt { object["updatedAt"] = now.timeIntervalSince1970 }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(bytes: data, encoding: .utf8) else { return "" }
        return json
    }

    // MARK: - v1 JSON

    @Test("v1 active lifetime (no expiresAt) grants")
    func v1ActiveLifetimeGrants() {
        let raw = Self.v1JSON(status: "active", period: "lifetime", expiresAt: nil)
        #expect(CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("v1 active subscription with a future expiry grants")
    func v1ActiveFutureExpiryGrants() {
        let raw = Self.v1JSON(status: "active", expiresAt: Self.now.addingTimeInterval(86_400))
        #expect(CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("v1 active subscription expired beyond the grace window does not grant")
    func v1ExpiredBeyondGraceDenied() {
        let expiry = Self.now.addingTimeInterval(-Self.grace - 60)
        let raw = Self.v1JSON(status: "active", expiresAt: expiry)
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("v1 active subscription inside the 7-day renewal grace still grants")
    func v1InsideGraceGrants() {
        let expiry = Self.now.addingTimeInterval(-Self.grace + 60)
        let raw = Self.v1JSON(status: "active", expiresAt: expiry)
        #expect(CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("Grace window ends exactly at expiresAt + 7 days")
    func graceBoundaryIsExclusive() {
        let expiry = Self.now.addingTimeInterval(-Self.grace)
        let raw = Self.v1JSON(status: "active", expiresAt: expiry)
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("status \"grace\" is honored like active")
    func graceStatusGrants() {
        let raw = Self.v1JSON(status: "grace", expiresAt: Self.now.addingTimeInterval(86_400))
        #expect(CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("status \"expired\" never grants, even with a future expiry")
    func expiredStatusDenied() {
        let raw = Self.v1JSON(status: "expired", expiresAt: Self.now.addingTimeInterval(86_400))
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    @Test("Unknown status values do not grant")
    func unknownStatusDenied() {
        let raw = Self.v1JSON(status: "refunded", expiresAt: nil)
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    // MARK: - Legacy v0

    @Test("Legacy bare \"active\" string is treated as an active lifetime grant")
    func legacyActiveStringGrants() {
        #expect(CrossAppEntitlementReader.grantsPlus(rawValue: "active", now: Self.now))
        let mirror = CrossAppEntitlementReader.decode("active")
        #expect(mirror?.status == "active")
        #expect(mirror?.period == "lifetime")
        #expect(mirror?.expiresAt == nil)
    }

    @Test("Other bare strings do not grant")
    func legacyOtherStringDenied() {
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: "inactive", now: Self.now))
    }

    // MARK: - Absent / malformed

    @Test("Missing keychain item does not grant")
    func missingItemDenied() {
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: nil, now: Self.now))
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: "", now: Self.now))
    }

    @Test("Malformed JSON does not grant")
    func malformedJSONDenied() {
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: "{\"v\":1,\"status\":", now: Self.now))
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: "[1,2,3]", now: Self.now))
        #expect(CrossAppEntitlementReader.decode("not json at all") == nil)
    }

    @Test("JSON missing a required contract field does not grant")
    func incompleteJSONDenied() {
        // No `updatedAt` — outside the contract, so it must not be honored.
        let raw = Self.v1JSON(status: "active", expiresAt: nil, includeUpdatedAt: false)
        #expect(!CrossAppEntitlementReader.grantsPlus(rawValue: raw, now: Self.now))
    }

    // MARK: - Decode fidelity

    @Test("v1 payload decodes period and expiry as unix seconds")
    func decodePreservesFields() throws {
        let expiry = Self.now.addingTimeInterval(3_600)
        let raw = Self.v1JSON(status: "active", period: "monthly", expiresAt: expiry)
        let mirror = try #require(CrossAppEntitlementReader.decode(raw))
        #expect(mirror.v == 1)
        #expect(mirror.period == "monthly")
        #expect(mirror.status == "active")
        #expect(mirror.expiresAt?.timeIntervalSince1970 == expiry.timeIntervalSince1970)
    }

    @Test("Renewal grace matches the 7-day contract")
    func renewalGraceIsSevenDays() {
        #expect(CrossAppEntitlementReader.renewalGrace == 7 * 24 * 60 * 60)
    }
}
