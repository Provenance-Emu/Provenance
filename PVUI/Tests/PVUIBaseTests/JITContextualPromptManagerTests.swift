//
//  JITContextualPromptManagerTests.swift
//  PVUIBaseTests
//
//  Unit tests for JITContextualPromptManager.recommendation(...)
//

import Testing
@testable import PVUIBase
import PVSettings
import Defaults

@MainActor
@Suite("JITContextualPromptManager Tests")
struct JITContextualPromptManagerTests {

    // MARK: - Helpers

    private let manager = JITContextualPromptManager.shared

    private func setPreference(_ pref: JITGamePreference, forMD5 md5: String) {
        Defaults.setJITPreference(pref, forGameMD5: md5)
    }

    private func clearPreference(forMD5 md5: String) {
        Defaults.setJITPreference(.automatic, forGameMD5: md5)
    }

    /// Runs `body` with a clean slate for `jitGamePreferences`, restoring the
    /// original value when done.  All test cases that touch per-game preferences
    /// should call this wrapper so that prior-run or parallel-test state cannot
    /// influence results.
    private func withIsolatedPreferences(_ body: () -> Void) {
        let snapshot = Defaults[.jitGamePreferences]
        defer { Defaults[.jitGamePreferences] = snapshot }
        body()
    }

    // MARK: - Non-JIT cores

    @Test("Non-JIT core returns .proceed regardless of preference")
    func nonJITCoreReturnsProceed() {
        let result = manager.recommendation(
            forGameMD5: "testmd5",
            coreIdentifier: "com.provenance.snes9x",
            coreName: "Snes9x"
        )
        #expect(result == .proceed)
    }

    // MARK: - Required-core behaviour

    @Test("Required core always shows blocking warning, even with skipJIT preference")
    func requiredCoreIgnoresSkipJITPreference() {
        withIsolatedPreferences {
            setPreference(.skipJIT, forMD5: "ps2md5")
            let result = manager.recommendation(
                forGameMD5: "ps2md5",
                coreIdentifier: "com.provenance.pcsx2",
                coreName: "Play!"
            )
            if case .showRequiredWarning = result {
                // expected — skipJIT must not suppress a required-core warning
            } else {
                Issue.record("Expected .showRequiredWarning, got \(result)")
            }
        }
    }

    @Test("Required core shows blocking warning with automatic preference")
    func requiredCoreShowsBlockingWarning() {
        withIsolatedPreferences {
            let result = manager.recommendation(
                forGameMD5: "ps2md5_auto",
                coreIdentifier: "ps2",
                coreName: "Play!"
            )
            if case .showRequiredWarning = result {
                // expected
            } else {
                Issue.record("Expected .showRequiredWarning, got \(result)")
            }
        }
    }

    // MARK: - skipJIT preference (optional cores)

    @Test("skipJIT preference returns .skipJIT for optional-JIT core")
    func skipJITPreferenceReturnsSkipJIT() {
        withIsolatedPreferences {
            setPreference(.skipJIT, forMD5: "n64md5")
            manager.resetSessionState()
            let result = manager.recommendation(
                forGameMD5: "n64md5",
                coreIdentifier: "mupen",
                coreName: "Mupen64Plus"
            )
            #expect(result == .skipJIT)
        }
    }

    // MARK: - preferJIT preference

    @Test("preferJIT preference always shows recommended prompt for optional-JIT core")
    func preferJITAlwaysPrompts() {
        withIsolatedPreferences {
            setPreference(.preferJIT, forMD5: "n64md5_prefer")
            manager.resetSessionState()
            // First call
            let r1 = manager.recommendation(forGameMD5: "n64md5_prefer", coreIdentifier: "mupen", coreName: "Mupen64Plus")
            // Second call — should still show (not suppressed after first)
            let r2 = manager.recommendation(forGameMD5: "n64md5_prefer", coreIdentifier: "mupen", coreName: "Mupen64Plus")
            if case .showRecommendedPrompt = r1 { } else { Issue.record("First call: expected .showRecommendedPrompt, got \(r1)") }
            if case .showRecommendedPrompt = r2 { } else { Issue.record("Second call: expected .showRecommendedPrompt, got \(r2)") }
        }
    }

    // MARK: - Once-per-session suppression

    @Test("automatic preference shows prompt once per session per core")
    func automaticShowsOncePerSession() {
        withIsolatedPreferences {
            manager.resetSessionState()
            let r1 = manager.recommendation(forGameMD5: "psp_auto", coreIdentifier: "ppsspp", coreName: "PPSSPP")
            let r2 = manager.recommendation(forGameMD5: "psp_auto", coreIdentifier: "ppsspp", coreName: "PPSSPP")
            if case .showRecommendedPrompt = r1 { } else { Issue.record("First call: expected .showRecommendedPrompt, got \(r1)") }
            #expect(r2 == .proceed, "Second call within session should be suppressed")
        }
    }

    @Test("resetSessionState clears per-session suppression")
    func resetSessionStateRestoresPrompt() {
        withIsolatedPreferences {
            manager.resetSessionState()
            _ = manager.recommendation(forGameMD5: "psp_reset", coreIdentifier: "ppsspp", coreName: "PPSSPP")
            manager.resetSessionState()
            let result = manager.recommendation(forGameMD5: "psp_reset", coreIdentifier: "ppsspp", coreName: "PPSSPP")
            if case .showRecommendedPrompt = result { } else {
                Issue.record("After reset, expected .showRecommendedPrompt, got \(result)")
            }
        }
    }
}
