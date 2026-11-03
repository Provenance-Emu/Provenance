//
//  EmulatorQuickActionBarTests.swift
//  PVUIBaseTests
//
//  Which quick-action buttons desktop input mode shows for a core's capabilities.
//

#if os(iOS) && !targetEnvironment(macCatalyst)
import Testing
@testable import PVUIBase

@Suite("Desktop quick-action bar")
struct EmulatorQuickActionBarTests {
    private typealias Bar = EmulatorQuickActionBar

    private static func capabilities(saves: Bool = false, keyboard: Bool = false, mouse: Bool = false,
                                     recording: Bool = false) -> Bar.Capabilities {
        Bar.Capabilities(supportsSaveStates: saves, supportsKeyboard: keyboard, supportsMouse: mouse,
                         recordingAvailable: recording)
    }

    @Test("A core with no extras still gets fast-forward, and nothing on the leading edge")
    func minimal() {
        let rows = Bar.rows(for: Self.capabilities())
        #expect(rows.trailing == [.fastForward])
        #expect(rows.leading.isEmpty)
    }

    @Test("Everything supported: record, quick save, quick load, then fast-forward at the trailing edge")
    func everything() {
        let rows = Bar.rows(for: Self.capabilities(saves: true, keyboard: true, mouse: true, recording: true))
        #expect(rows.trailing == [.record, .quickSave, .quickLoad, .fastForward])
        #expect(rows.leading == [.keyboard, .mouse])
    }

    @Test("Save states add both quick save and quick load")
    func saveStates() {
        #expect(Bar.rows(for: Self.capabilities(saves: true)).trailing == [.quickSave, .quickLoad, .fastForward])
    }

    @Test("Keyboard and mouse toggles appear only for cores that take them")
    func keyboardAndMouse() {
        #expect(Bar.rows(for: Self.capabilities(keyboard: true)).leading == [.keyboard])
        #expect(Bar.rows(for: Self.capabilities(mouse: true)).leading == [.mouse])
    }

    @Test("Recording shows only when the recorder is available")
    func recording() {
        #expect(Bar.rows(for: Self.capabilities(recording: true)).trailing == [.record, .fastForward])
    }
}
#endif
