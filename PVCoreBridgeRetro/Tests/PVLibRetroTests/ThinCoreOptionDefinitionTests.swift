//
//  ThinCoreOptionDefinitionTests.swift
//  PVLibRetroTests
//
//  The options UI stores what the user sees (a switch state, a choice label);
//  the core only understands its own raw value strings. These cover the
//  translation between the two.
//

import Testing
import Foundation
@testable import PVCoreBridgeRetro

@Suite("ThinCoreOptionDefinition")
struct ThinCoreOptionDefinitionTests {

    private func choices(_ pairs: [(String, String)]) -> [ThinCoreOptionDefinition.Choice] {
        pairs.map { ThinCoreOptionDefinition.Choice(value: $0.0, label: $0.1) }
    }

    private func toggle(order: [String], defaultValue: String = "disabled") -> ThinCoreOptionDefinition {
        ThinCoreOptionDefinition(
            key: "core_toggle",
            title: "Toggle",
            defaultValue: defaultValue,
            choices: choices(order.map { ($0, $0) })
        )
    }

    private var resolution: ThinCoreOptionDefinition {
        ThinCoreOptionDefinition(
            key: "core_resolution",
            title: "Internal Resolution",
            defaultValue: "640x480",
            choices: choices([("320x240", "320x240 (0.5x)"), ("640x480", "640x480 (1x)"), ("1280x960", "1280x960 (2x)")])
        )
    }

    // MARK: Parsing

    @Test("Decodes the frontend's dictionary, treating NSNull fields as absent")
    func decodesDictionary() throws {
        let definition = try #require(ThinCoreOptionDefinition([
            "key": "core_resolution",
            "desc": "Internal Resolution",
            "info": NSNull(),
            "category": NSNull(),
            "default": "640x480",
            "values": [["value": "640x480", "label": "640x480 (1x)"], ["value": "1280x960"]]
        ]))
        #expect(definition.key == "core_resolution")
        #expect(definition.title == "Internal Resolution")
        #expect(definition.info == nil)
        #expect(definition.categoryKey == nil)
        #expect(definition.choices == choices([("640x480", "640x480 (1x)"), ("1280x960", "1280x960")]))
    }

    @Test("A definition without a key is rejected")
    func rejectsMissingKey() {
        #expect(ThinCoreOptionDefinition(["desc": "Orphan"]) == nil)
    }

    // MARK: Toggles

    @Test("On/off roles come from the words, not the order the core lists them",
          arguments: [["enabled", "disabled"], ["disabled", "enabled"], ["OFF", "ON"], ["true", "false"], ["0", "1"]])
    func toggleRolesIndependentOfOrder(order: [String]) throws {
        let definition = toggle(order: order)
        let values = try #require(definition.toggleValues)
        #expect(definition.isOn(values.on))
        #expect(!definition.isOn(values.off))
        #expect(definition.rawValue(forStored: true) == values.on)
        #expect(definition.rawValue(forStored: false) == values.off)
    }

    @Test("Two arbitrary choices are not a toggle")
    func twoChoicesNotAToggle() {
        let definition = ThinCoreOptionDefinition(
            key: "core_region",
            title: "Region",
            defaultValue: "ntsc",
            choices: choices([("ntsc", "NTSC"), ("pal", "PAL")])
        )
        #expect(definition.toggleValues == nil)
    }

    @Test("A switch state read back from UserDefaults maps like a live one")
    func toggleFromUserDefaultsObject() {
        let definition = toggle(order: ["disabled", "enabled"])
        #expect(definition.rawValue(forStored: NSNumber(value: true)) == "enabled")
        #expect(definition.rawValue(forStored: NSNumber(value: false)) == "disabled")
    }

    // MARK: Choices

    @Test("A choice label is sent to the core as its raw value")
    func labelMapsToValue() {
        #expect(resolution.rawValue(forStored: "1280x960 (2x)") == "1280x960")
    }

    @Test("A raw value is accepted as-is")
    func rawValuePassesThrough() {
        #expect(resolution.rawValue(forStored: "320x240") == "320x240")
    }

    @Test("A legacy choice index resolves to that choice's value")
    func legacyIndex() {
        #expect(resolution.rawValue(forStored: 2) == "1280x960")
        #expect(resolution.rawValue(forStored: 9) == nil)
    }

    @Test("A value the core no longer offers is dropped rather than forwarded")
    func unknownValueDropped() {
        #expect(resolution.rawValue(forStored: "4K") == nil)
    }
}
