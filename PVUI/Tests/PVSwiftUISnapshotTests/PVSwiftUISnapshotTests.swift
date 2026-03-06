//
//  PVSwiftUISnapshotTests.swift
//  PVUI — Milestone 3: Prefire snapshot tests
//
//  The Prefire build plugin (PrefirePlugin) auto-scans #Preview macros in
//  PVSwiftUI at build time and emits PrefireTests.generated.swift, which adds
//  XCTestCase snapshot assertions for every preview automatically.
//
//  This file provides supplementary hand-written snapshot tests for views that
//  can be constructed with only lightweight dependencies (no Realm, no AppState).
//
//  Baseline recording (first run, or after intentional visual changes):
//    xcodebuild test \
//      -workspace Provenance.xcworkspace \
//      -scheme Provenance-Screenshots \
//      -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
//      -only-testing:PVSwiftUISnapshotTests \
//      OTHER_SWIFT_FLAGS="-DrecordSnapshots"
//
//  Snapshot baselines (PNG) are stored under __Snapshots__/ and committed so
//  CI can detect visual regressions across PRs.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import PVSwiftUI

// MARK: - ErrorView
//
// ErrorView only depends on ThemeManager.shared (a lightweight singleton)
// and is a good candidate for isolated snapshot regression testing.

final class ErrorViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Uncomment to re-record baselines after intentional visual changes:
        // isRecording = true
    }

    func testErrorView_iPhonePro() {
        let error = NSError(
            domain: "com.provenance.emu",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Could not load the game library. Check your ROM folder path in Settings and try again."
            ]
        )
        let view = ErrorView(error: error, retryAction: {})
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro),
            named: "ErrorView_iPhone13Pro"
        )
    }

    func testErrorView_iPhoneSE() {
        let error = NSError(
            domain: "com.provenance.emu",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not load the game library."]
        )
        let view = ErrorView(error: error, retryAction: {})
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhoneSe),
            named: "ErrorView_iPhoneSE"
        )
    }

    func testErrorView_darkMode() {
        let error = NSError(
            domain: "com.provenance.emu",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not load the game library."]
        )
        let view = ErrorView(error: error, retryAction: {})
            .environment(\.colorScheme, .dark)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro),
            named: "ErrorView_iPhone13Pro_dark"
        )
    }
}

// MARK: - FX views (animation-free snapshot)
//
// These are visual-only views with no external dependencies.
// Snapshot precision is relaxed (0.90) for animated views captured at a point in time.

@available(iOS 18.0, *)
final class FXViewSnapshotTests: XCTestCase {

    func testAnimatedCheckerboardView() {
        let view = AnimatedCheckerboardView()
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13Pro, precision: 0.90),
            named: "AnimatedCheckerboardView_iPhone13Pro"
        )
    }
}
