//
//  MultiSelectToolbarStateTests.swift
//  PVUIBaseTests
//

import Testing
@testable import PVUIBase

/// `MultiSelectToolbarState` is a process-wide singleton, so these run serialized.
@MainActor
@Suite("MultiSelectToolbarState", .serialized)
struct MultiSelectToolbarStateTests {

    @Test("Activate shows the toolbar with a clean count and no cloud actions")
    func activateResetsState() {
        let state = MultiSelectToolbarState.shared
        state.deactivate()
        state.updateCount(3)
        state.canOffload = true
        state.canDownload = true

        state.activate()

        #expect(state.isActive)
        #expect(state.selectedCount == 0)
        #expect(!state.canOffload)
        #expect(!state.canDownload)
        state.deactivate()
    }

    @Test("updateCount tracks the selection size")
    func updateCountTracksSelection() {
        let state = MultiSelectToolbarState.shared
        state.activate()
        state.updateCount(5)
        #expect(state.selectedCount == 5)
        state.updateCount(0)
        #expect(state.selectedCount == 0)
        state.deactivate()
    }

    @Test("Deactivate hides the toolbar and drops every bound action")
    func deactivateClearsCallbacks() {
        let state = MultiSelectToolbarState.shared
        state.activate()
        state.updateCount(2)
        state.onDelete = {}
        state.onMoveToSystem = {}
        state.onDone = {}
        state.onSelectAll = {}
        state.onDeselectAll = {}

        state.deactivate()

        #expect(!state.isActive)
        #expect(state.selectedCount == 0)
        #expect(state.onDelete == nil)
        #expect(state.onMoveToSystem == nil)
        #expect(state.onDone == nil)
        #expect(state.onSelectAll == nil)
        #expect(state.onDeselectAll == nil)
    }
}
