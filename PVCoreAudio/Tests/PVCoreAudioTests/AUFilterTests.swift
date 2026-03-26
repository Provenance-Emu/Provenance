//
//  AUFilterTests.swift
//  PVCoreAudioTests
//
//  Part of #3489 — AU filter support
//

@testable import PVCoreAudio
import XCTest

final class AUFilterTests: XCTestCase {

    // MARK: - AUEffectType

    func testAllEffectTypesHaveDefaultParameters() {
        for effectType in AUEffectType.allCases {
            XCTAssertFalse(effectType.defaultParameters.isEmpty,
                           "\(effectType) should have at least one default parameter")
        }
    }

    func testAllEffectTypesHaveParameterDefinitions() {
        for effectType in AUEffectType.allCases {
            XCTAssertFalse(effectType.parameterDefinitions.isEmpty,
                           "\(effectType) should expose at least one parameter definition")
        }
    }

    func testAllEffectTypesHaveDisplayName() {
        for effectType in AUEffectType.allCases {
            XCTAssertFalse(effectType.description.isEmpty,
                           "\(effectType) must have a non-empty display name")
        }
    }

    // MARK: - AUEffectNode

    func testNodeUsesDefaultParametersOnInit() {
        for effectType in AUEffectType.allCases {
            let node = AUEffectNode(effectType: effectType)
            XCTAssertEqual(node.parameters, effectType.defaultParameters)
            XCTAssertTrue(node.isEnabled)
        }
    }

    func testNodeHasUniqueIDOnEachInit() {
        let a = AUEffectNode(effectType: .reverb)
        let b = AUEffectNode(effectType: .reverb)
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - AUEffectsChain

    func testEmptyChainHasNoActiveEffects() {
        XCTAssertFalse(AUEffectsChain.empty.hasActiveEffects)
        XCTAssertTrue(AUEffectsChain.empty.activeNodes.isEmpty)
    }

    func testChainWithDisabledMasterHasNoActiveEffects() {
        let node = AUEffectNode(effectType: .reverb)
        let chain = AUEffectsChain(nodes: [node], isEnabled: false)
        XCTAssertFalse(chain.hasActiveEffects)
        XCTAssertTrue(chain.activeNodes.isEmpty)
    }

    func testChainActiveNodesFiltersDisabledNodes() {
        var enabledNode = AUEffectNode(effectType: .reverb)
        enabledNode.isEnabled = true
        var disabledNode = AUEffectNode(effectType: .delay)
        disabledNode.isEnabled = false

        let chain = AUEffectsChain(nodes: [enabledNode, disabledNode], isEnabled: true)
        XCTAssertEqual(chain.activeNodes.count, 1)
        XCTAssertEqual(chain.activeNodes.first?.effectType, .reverb)
    }

    // MARK: - AUEffectsPreset

    func testBuiltinPresetsAreNotEmpty() {
        XCTAssertFalse(AUEffectsPreset.builtinPresets.isEmpty)
    }

    func testBuiltinPresetsHaveUniqueIDs() {
        let ids = AUEffectsPreset.builtinPresets.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Builtin presets must have unique IDs")
    }

    func testBuiltinPresetsHaveNonEmptyNames() {
        for preset in AUEffectsPreset.builtinPresets {
            XCTAssertFalse(preset.name.isEmpty)
        }
    }

    // MARK: - Codable round-trip

    func testChainCodableRoundTrip() throws {
        var node = AUEffectNode(effectType: .delay)
        node.parameters[AUEffectParameterKey.delayTime] = 0.5
        let chain = AUEffectsChain(nodes: [node], isEnabled: true)

        let data = try JSONEncoder().encode(chain)
        let decoded = try JSONDecoder().decode(AUEffectsChain.self, from: data)

        XCTAssertEqual(decoded.isEnabled, chain.isEnabled)
        XCTAssertEqual(decoded.nodes.count, 1)
        XCTAssertEqual(decoded.nodes.first?.effectType, .delay)
        XCTAssertEqual(decoded.nodes.first?.parameters[AUEffectParameterKey.delayTime], 0.5)
    }

    func testPresetCodableRoundTrip() throws {
        let reverb = AUEffectNode(effectType: .reverb)
        let chain = AUEffectsChain(nodes: [reverb], isEnabled: true)
        let preset = AUEffectsPreset(name: "Test Preset", chain: chain)

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(AUEffectsPreset.self, from: data)

        XCTAssertEqual(decoded.name, "Test Preset")
        XCTAssertEqual(decoded.chain.nodes.count, 1)
    }
}
