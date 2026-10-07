//
//  ProgrammaticOverlaySupportTests.swift
//  PVUIBaseTests
//
//  When the programmatic overlay applies to a game, and the overlay notification payloads
//  the emulator view controller decodes.
//

import Foundation
import Testing
import PVSystems
@testable import PVUIBase

@Suite("ProgrammaticOverlaySupport")
struct ProgrammaticOverlaySupportTests {
    @Test("The linked system wins; the persisted identifier is the fallback")
    func systemIdentifierResolution() {
        #expect(ProgrammaticOverlaySupport.systemIdentifier(linked: .SNES, persisted: SystemIdentifier.NES.rawValue)
                == .SNES)
        #expect(ProgrammaticOverlaySupport.systemIdentifier(linked: nil, persisted: SystemIdentifier.DS.rawValue)
                == .DS)
        #expect(ProgrammaticOverlaySupport.systemIdentifier(linked: nil, persisted: "not-a-system") == nil)
    }

    @Test("Covers a bound system only while the setting is on")
    func covers() {
        #expect(ProgrammaticOverlaySupport.covers(.SNES, enabled: true))
        #expect(ProgrammaticOverlaySupport.covers(.GameCube, enabled: true))
        #expect(!ProgrammaticOverlaySupport.covers(.SNES, enabled: false))
        #expect(!ProgrammaticOverlaySupport.covers(nil, enabled: true))
    }

    @Test("Systems without an overlay binding are not covered")
    func unboundSystem() {
        #expect(!ProgrammaticOverlaySupport.covers(._3DS, enabled: true))
    }
}

@Suite("OverlayNotificationPayload")
struct OverlayNotificationPayloadTests {
    @Test("Frames round-trip in order; a missing payload reads as no frames (overlay not mounted)")
    func frames() {
        let frames = [CGRect(x: 0, y: 40, width: 390, height: 292), CGRect(x: 0, y: 340, width: 390, height: 292)]
        #expect(OverlayNotificationPayload.frames(from: OverlayNotificationPayload.userInfo(frames: frames)) == frames)
        #expect(OverlayNotificationPayload.frames(from: OverlayNotificationPayload.userInfo(frames: [])).isEmpty)
        #expect(OverlayNotificationPayload.frames(from: nil).isEmpty)
        #expect(OverlayNotificationPayload.frames(from: ["frames": "garbage"]).isEmpty)
    }

    @Test("Editing state round-trips; a missing payload is nil")
    func editing() {
        #expect(OverlayNotificationPayload.editing(from: OverlayNotificationPayload.userInfo(editing: true)) == true)
        #expect(OverlayNotificationPayload.editing(from: OverlayNotificationPayload.userInfo(editing: false)) == false)
        #expect(OverlayNotificationPayload.editing(from: nil) == nil)
    }
}
