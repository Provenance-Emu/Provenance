//
//  DualSenseMicButtonActionTests.swift
//  PVSettings
//
//  The key moved from String to an enum; values stored before that must still read back.
//

import Testing
@testable import PVSettings
import Defaults
import Foundation

@Suite("DualSenseMicButtonAction storage", .serialized)
struct DualSenseMicButtonActionTests {

    private static let suiteName = "DualSenseMicButtonActionTests"

    private func freshSuite() throws -> UserDefaults {
        let suite = try #require(UserDefaults(suiteName: Self.suiteName))
        suite.removePersistentDomain(forName: Self.suiteName)
        return suite
    }

    private func key(in suite: UserDefaults) -> Defaults.Key<DualSenseMicButtonAction> {
        Defaults.Key(Defaults.Keys.dualSenseMicButtonAction.name, default: .muteAudio, suite: suite)
    }

    @Test("Strings stored by the old String key read back as the matching case")
    func legacyStringsDecode() throws {
        let suite = try freshSuite()
        suite.set("none", forKey: Defaults.Keys.dualSenseMicButtonAction.name)
        #expect(Defaults[key(in: suite)] == .doNothing)
        suite.set("muteAudio", forKey: Defaults.Keys.dualSenseMicButtonAction.name)
        #expect(Defaults[key(in: suite)] == .muteAudio)
    }

    @Test("A case is written as its raw string")
    func writesRawString() throws {
        let suite = try freshSuite()
        Defaults[key(in: suite)] = .doNothing
        #expect(suite.string(forKey: Defaults.Keys.dualSenseMicButtonAction.name) == "none")
    }

    @Test("An unknown stored value falls back to the default")
    func unknownFallsBack() throws {
        let suite = try freshSuite()
        suite.set("launchMissiles", forKey: Defaults.Keys.dualSenseMicButtonAction.name)
        #expect(Defaults[key(in: suite)] == .muteAudio)
    }

    @Test("The default mutes audio")
    func defaultValue() {
        #expect(Defaults.Keys.dualSenseMicButtonAction.defaultValue == .muteAudio)
    }
}
