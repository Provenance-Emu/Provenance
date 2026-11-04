//
//  SettingsPresentationTests.swift
//  PVUIBaseTests
//

#if canImport(UIKit)
import Testing
import UIKit
@testable import PVUIBase

/// Settings fills the window on iPad only (#3780); iPhone keeps its sheet.
@Suite("SettingsPresentation")
struct SettingsPresentationTests {
    @Test func padFillsScreen() {
        #expect(SettingsPresentation.fillsScreen(for: .pad))
    }

    @Test func phoneKeepsTheSheet() {
        #expect(!SettingsPresentation.fillsScreen(for: .phone))
    }

    @Test func otherIdiomsKeepTheSheet() {
        #expect(!SettingsPresentation.fillsScreen(for: .tv))
        #expect(!SettingsPresentation.fillsScreen(for: .mac))
        #expect(!SettingsPresentation.fillsScreen(for: .unspecified))
    }
}
#endif
