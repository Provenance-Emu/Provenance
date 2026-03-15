//
//  DeltaSkinModelTests.swift
//  PVUIBaseTests
//
//  Unit tests for new DeltaSkin model types added for Manic EMU feature parity:
//  DeltaSkinHaptic, DeltaSkinBackgroundAnimation, DeltaSkinButtonStates,
//  and DeltaSkinValidationResult.
//

import Foundation
import Testing
@testable import PVUIBase

// MARK: - DeltaSkinHaptic Tests

@Suite("DeltaSkinHaptic")
struct DeltaSkinHapticTests {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    @Test("Default init produces medium/1.0")
    func defaultInit() {
        let h = DeltaSkinHaptic()
        #expect(h.style == "medium")
        #expect(h.intensity == 1.0)
    }

    @Test("Full JSON round-trips correctly")
    func fullRoundTrip() throws {
        let json = #"{"style":"light","intensity":0.5}"#.data(using: .utf8)!
        let h = try decoder.decode(DeltaSkinHaptic.self, from: json)
        #expect(h.style == "light")
        #expect(h.intensity == 0.5)
        let encoded = try encoder.encode(h)
        let h2 = try decoder.decode(DeltaSkinHaptic.self, from: encoded)
        #expect(h2 == h)
    }

    @Test("Missing style defaults to medium")
    func missingStyleDefaultsMedium() throws {
        let json = #"{"intensity":0.75}"#.data(using: .utf8)!
        let h = try decoder.decode(DeltaSkinHaptic.self, from: json)
        #expect(h.style == "medium")
        #expect(h.intensity == 0.75)
    }

    @Test("Missing intensity defaults to 1.0")
    func missingIntensityDefaultsOne() throws {
        let json = #"{"style":"heavy"}"#.data(using: .utf8)!
        let h = try decoder.decode(DeltaSkinHaptic.self, from: json)
        #expect(h.style == "heavy")
        #expect(h.intensity == 1.0)
    }

    @Test("Empty JSON object uses all defaults")
    func emptyObjectUsesDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let h = try decoder.decode(DeltaSkinHaptic.self, from: json)
        #expect(h.style == "medium")
        #expect(h.intensity == 1.0)
    }

    @Test("Equatable works as expected")
    func equatable() {
        let a = DeltaSkinHaptic(style: "light", intensity: 0.3)
        let b = DeltaSkinHaptic(style: "light", intensity: 0.3)
        let c = DeltaSkinHaptic(style: "heavy", intensity: 0.3)
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - DeltaSkinBackgroundAnimation Tests

@Suite("DeltaSkinBackgroundAnimation")
struct DeltaSkinBackgroundAnimationTests {

    private let decoder = JSONDecoder()

    @Test("Frame-sequence type decodes correctly")
    func frameSequenceType() throws {
        let json = #"""
        {
          "type": "frames",
          "frames": ["bg_f0.png", "bg_f1.png"],
          "fps": 8,
          "loops": true
        }
        """#.data(using: .utf8)!
        let anim = try decoder.decode(DeltaSkinBackgroundAnimation.self, from: json)
        #expect(anim.type == .frames)
        #expect(anim.frames == ["bg_f0.png", "bg_f1.png"])
        #expect(anim.fps == 8)
        #expect(anim.loops == true)
        #expect(anim.file == nil)
    }

    @Test("APNG type decodes correctly")
    func apngType() throws {
        let json = #"{"type":"apng","file":"bg.apng","fps":24,"loops":false}"#.data(using: .utf8)!
        let anim = try decoder.decode(DeltaSkinBackgroundAnimation.self, from: json)
        #expect(anim.type == .apng)
        #expect(anim.file == "bg.apng")
        #expect(anim.fps == 24)
        #expect(anim.loops == false)
        #expect(anim.frames == nil)
    }

    @Test("GIF type decodes correctly")
    func gifType() throws {
        let json = #"{"type":"gif","file":"bg.gif"}"#.data(using: .utf8)!
        let anim = try decoder.decode(DeltaSkinBackgroundAnimation.self, from: json)
        #expect(anim.type == .gif)
        #expect(anim.file == "bg.gif")
        #expect(anim.fps == nil)
        #expect(anim.loops == nil)
    }

    @Test("Invalid type throws decoding error")
    func invalidTypeThrows() {
        let json = #"{"type":"unknown"}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(DeltaSkinBackgroundAnimation.self, from: json)
        }
    }

    @Test("All three type raw values match spec")
    func typeRawValues() {
        #expect(DeltaSkinBackgroundAnimationType.frames.rawValue == "frames")
        #expect(DeltaSkinBackgroundAnimationType.apng.rawValue == "apng")
        #expect(DeltaSkinBackgroundAnimationType.gif.rawValue == "gif")
    }
}

// MARK: - DeltaSkinButtonStates Tests

@Suite("DeltaSkinButtonStates")
struct DeltaSkinButtonStatesTests {

    private let decoder = JSONDecoder()

    @Test("Normal and pressed images decode correctly")
    func normalAndPressedDecode() throws {
        let json = #"""
        {
          "normal": {"image": "btn_normal.png"},
          "pressed": {"image": "btn_pressed.png"}
        }
        """#.data(using: .utf8)!
        let states = try decoder.decode(DeltaSkinButtonStates.self, from: json)
        #expect(states.normal?.image == "btn_normal.png")
        #expect(states.pressed?.image == "btn_pressed.png")
        #expect(states.animated == nil)
    }

    @Test("Animated block decodes correctly")
    func animatedBlockDecodes() throws {
        let json = #"""
        {
          "normal": {"image": "btn_normal.png"},
          "animated": {"frames": ["f0.png","f1.png","f2.png"], "fps": 12, "loops": true}
        }
        """#.data(using: .utf8)!
        let states = try decoder.decode(DeltaSkinButtonStates.self, from: json)
        #expect(states.animated?.frames == ["f0.png", "f1.png", "f2.png"])
        #expect(states.animated?.fps == 12)
        #expect(states.animated?.loops == true)
    }

    @Test("All-nil states decode from empty object")
    func allNilFromEmptyObject() throws {
        let json = "{}".data(using: .utf8)!
        let states = try decoder.decode(DeltaSkinButtonStates.self, from: json)
        #expect(states.normal == nil)
        #expect(states.pressed == nil)
        #expect(states.animated == nil)
    }

    @Test("ButtonStateImage round-trips")
    func stateImageRoundTrip() throws {
        let original = DeltaSkinButtonStateImage(image: "foo.png")
        let data = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(DeltaSkinButtonStateImage.self, from: data)
        #expect(decoded == original)
    }

    @Test("ButtonAnimated equality")
    func buttonAnimatedEquality() {
        let a = DeltaSkinButtonAnimated(frames: ["f0.png"], fps: 8, loops: true)
        let b = DeltaSkinButtonAnimated(frames: ["f0.png"], fps: 8, loops: true)
        let c = DeltaSkinButtonAnimated(frames: ["f1.png"], fps: 8, loops: true)
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - DeltaSkinValidationResult Tests

@Suite("DeltaSkinValidationResult")
struct DeltaSkinValidationResultTests {

    private func finding(_ severity: DeltaSkinValidationSeverity, title: String = "T") -> DeltaSkinValidationFinding {
        DeltaSkinValidationFinding(severity: severity, title: title, detail: "d", suggestion: nil)
    }

    @Test("Empty findings → isValid true")
    func emptyFindingsIsValid() {
        let result = DeltaSkinValidationResult(findings: [])
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
        #expect(result.infos.isEmpty)
    }

    @Test("Warning-only result is still valid")
    func warningOnlyIsValid() {
        let result = DeltaSkinValidationResult(findings: [finding(.warning)])
        #expect(result.isValid)
        #expect(result.warnings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("Single error makes result invalid")
    func singleErrorInvalid() {
        let result = DeltaSkinValidationResult(findings: [finding(.error)])
        #expect(!result.isValid)
        #expect(result.errors.count == 1)
    }

    @Test("Mixed findings are bucketed correctly")
    func mixedFindingsBucketed() {
        let result = DeltaSkinValidationResult(findings: [
            finding(.info),
            finding(.warning),
            finding(.warning),
            finding(.error)
        ])
        #expect(result.infos.count == 1)
        #expect(result.warnings.count == 2)
        #expect(result.errors.count == 1)
        #expect(!result.isValid)
    }

    @Test("Finding has non-empty UUID id")
    func findingHasID() {
        let f = finding(.info)
        #expect(!f.id.uuidString.isEmpty)
    }

    @Test("Result has stable UUID id")
    func resultHasID() {
        let r = DeltaSkinValidationResult(findings: [])
        #expect(!r.id.uuidString.isEmpty)
    }

    @Test("Finding with suggestion stores it")
    func findingWithSuggestion() {
        let f = DeltaSkinValidationFinding(severity: .warning, title: "T", detail: "D", suggestion: "Fix it")
        #expect(f.suggestion == "Fix it")
    }
}
