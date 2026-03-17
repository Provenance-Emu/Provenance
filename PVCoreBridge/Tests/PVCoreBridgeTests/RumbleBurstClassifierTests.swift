//
//  RumbleBurstClassifierTests.swift
//  PVCoreBridgeTests
//
//  Unit tests for RumbleBurstClassifier and RumbleSystemProfile.
//

import XCTest
@testable import PVCoreBridge
import PVPrimitives

final class RumbleBurstClassifierTests: XCTestCase {

    // MARK: - RumbleBurstClassifier

    func testShortTransient_underThreshold() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.05)
        XCTAssertEqual(pattern, .shortTransient)
    }

    func testShortTransient_atBoundary() {
        // 79ms is just under the 80ms threshold
        let pattern = RumbleBurstClassifier.classify(duration: 0.079)
        XCTAssertEqual(pattern, .shortTransient)
    }

    func testMediumBurst_lowerBound() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.08)
        XCTAssertEqual(pattern, .mediumBurst)
    }

    func testMediumBurst_mid() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.15)
        XCTAssertEqual(pattern, .mediumBurst)
    }

    func testMediumBurst_upperBound() {
        // 249ms is just under the 250ms threshold
        let pattern = RumbleBurstClassifier.classify(duration: 0.249)
        XCTAssertEqual(pattern, .mediumBurst)
    }

    func testLongSustained_atThreshold() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.25)
        XCTAssertEqual(pattern, .longSustained)
    }

    func testLongSustained_extended() {
        let pattern = RumbleBurstClassifier.classify(duration: 1.5)
        XCTAssertEqual(pattern, .longSustained)
    }

    func testRapidPulse_triggersOnThreePulses() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.05, pulseCount: 3, windowDuration: 0.3)
        XCTAssertEqual(pattern, .rapidPulse)
    }

    func testRapidPulse_doesNotTriggerOnTwoPulses() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.05, pulseCount: 2, windowDuration: 0.3)
        XCTAssertEqual(pattern, .shortTransient)
    }

    func testRapidPulse_doesNotTriggerBeyondWindow() {
        // 3 pulses but in 600ms — beyond the 500ms rapid-pulse window
        let pattern = RumbleBurstClassifier.classify(duration: 0.05, pulseCount: 3, windowDuration: 0.6)
        XCTAssertEqual(pattern, .shortTransient)
    }

    func testRapidPulse_manyPulses() {
        let pattern = RumbleBurstClassifier.classify(duration: 0.04, pulseCount: 8, windowDuration: 0.4)
        XCTAssertEqual(pattern, .rapidPulse)
    }

    // MARK: - RumbleSystemProfile Lookup

    func testSystemProfile_n64() {
        let profile = RumbleSystemProfile.profile(forSystemIdentifier: "com.provenance.n64")
        XCTAssertEqual(profile.rumbleType, .rumblePak)
        XCTAssertGreaterThan(profile.lowFrequencyScale, profile.highFrequencyScale,
                             "N64 should be heavily low-frequency (ERM thump)")
        XCTAssertLessThan(profile.sharpness, 0.3, "N64 ERM should have low sharpness")
    }

    func testSystemProfile_psx() {
        let profile = RumbleSystemProfile.profile(forSystemIdentifier: "com.provenance.psx")
        XCTAssertEqual(profile.rumbleType, .dualMotor)
    }

    func testSystemProfile_gba() {
        let profile = RumbleSystemProfile.profile(forSystemIdentifier: "com.provenance.gba")
        XCTAssertEqual(profile.rumbleType, .singleMotor)
        XCTAssertGreaterThan(profile.highFrequencyScale, profile.lowFrequencyScale,
                             "GBA pager motor is high-frequency")
        XCTAssertGreaterThan(profile.sharpness, 0.7, "GBA pager motor should be sharp")
    }

    func testSystemProfile_unknownFallsBackToGeneric() {
        let profile = RumbleSystemProfile.profile(forSystemIdentifier: "com.provenance.atari2600")
        XCTAssertEqual(profile.rumbleType, .singleMotor)
    }

    func testSystemProfile_ps3DistinctFromPSX() {
        let ps3 = RumbleSystemProfile.profile(forSystemIdentifier: "com.provenance.ps3")
        let psx = RumbleSystemProfile.profile(forSystemIdentifier: "com.provenance.psx")
        // PS3 should not return the same profile as PSX (they are different presets)
        XCTAssertNotEqual(ps3.sharpness, psx.sharpness)
    }
}
