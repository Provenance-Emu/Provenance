//
//  SkinDevicePreferenceTests.swift
//  PVUIBaseTests
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
import SkinKitCore
@testable import PVUIBase

final class SkinDevicePreferenceTests: XCTestCase {
    func testPhoneAndTabletKeepTheirSingleDevice() {
        XCTAssertEqual(SkinDevicePreference.candidates(for: .phone), [.iphone])
        XCTAssertEqual(SkinDevicePreference.candidates(for: .tablet), [.ipad])
    }

    func testUnfoldedPhonePrefersIPadLayouts() {
        XCTAssertEqual(SkinDevicePreference.candidates(for: .expandedPhone), [.ipad, .iphone])
    }

    func testUnfoldedPhoneUsesIPadLayoutWhenTheSkinHasOne() {
        let device = SkinDevicePreference.device(among: [.ipad, .iphone]) { _ in true }
        XCTAssertEqual(device, .ipad)
    }

    func testUnfoldedPhoneFallsBackToIPhoneLayout() {
        let device = SkinDevicePreference.device(among: [.ipad, .iphone]) { $0 == .iphone }
        XCTAssertEqual(device, .iphone)
    }

    func testUnsupportedSkinKeepsTheBestCandidate() {
        XCTAssertEqual(SkinDevicePreference.device(among: [.ipad, .iphone]) { _ in false }, .ipad)
        XCTAssertEqual(SkinDevicePreference.device(among: [.iphone]) { _ in false }, .iphone)
    }

    func testNoSkinUsesTheBestCandidate() {
        let device = SkinDevicePreference.device(for: nil, orientation: .landscape, among: [.ipad, .iphone])
        XCTAssertEqual(device, .ipad)
    }
}
