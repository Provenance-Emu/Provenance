//
//  ImportSystemSelectionResumeTests.swift
//  PVUIBaseTests
//

import Testing
import PVLibrary
@testable import PVUIBase

@Suite("ImportSystemSelectionResume")
struct ImportSystemSelectionResumeTests {

    @Test("An idle importer is started so the resolved item is picked up")
    func idleStartsProcessing() {
        #expect(ImportSystemSelectionResume(processingState: .idle) == .startProcessing)
    }

    @Test("A paused importer processes only the item the user resolved")
    func pausedProcessesItem() {
        #expect(ImportSystemSelectionResume(processingState: .paused) == .processItem)
    }

    @Test("A running importer is left alone")
    func processingDoesNothing() {
        #expect(ImportSystemSelectionResume(processingState: .processing) == .nothing)
    }
}
