//
//  AUFilterTests.swift
//  PVCoreAudioTests
//
//  Part of #3489 — AU filter support
//

@testable import PVCoreAudio
import Defaults
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

    /// The master on/off switch is `Defaults[.auFiltersEnabled]`, **not** a flag on the chain.
    /// The production gate is
    /// `Defaults[.auFiltersEnabled] && chain.nodes.contains(where: \.isEnabled)`
    /// in `AVAudioEngineGameAudioEngine.updateSourceNode()`, so `hasActiveEffects` /
    /// `activeNodes` describe the chain *only* and must never consult the master toggle —
    /// if they did, the engine would be double-gating on it.
    ///
    /// This replaces the older `testChainWithDisabledMasterHasNoActiveEffects`, which passed a
    /// master flag to `AUEffectsChain.init` back when the chain owned one.
    func testChainActiveEffectsDoNotConsultTheGlobalToggle() {
        XCTAssertFalse(Defaults[.auFiltersEnabled], "The master toggle must ship off by default")

        var node = AUEffectNode(effectType: .reverb)
        node.isEnabled = true
        let chain = AUEffectsChain(nodes: [node])

        XCTAssertTrue(chain.hasActiveEffects,
                      "hasActiveEffects reports the chain's own nodes, independent of the master toggle")
        XCTAssertEqual(chain.activeNodes.count, 1)
    }

    func testChainActiveNodesFiltersDisabledNodes() {
        var enabledNode = AUEffectNode(effectType: .reverb)
        enabledNode.isEnabled = true
        var disabledNode = AUEffectNode(effectType: .delay)
        disabledNode.isEnabled = false

        let chain = AUEffectsChain(nodes: [enabledNode, disabledNode])
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
        var bypassed = AUEffectNode(effectType: .reverb)
        bypassed.isEnabled = false
        let chain = AUEffectsChain(nodes: [node, bypassed])

        let data = try JSONEncoder().encode(chain)
        let decoded = try JSONDecoder().decode(AUEffectsChain.self, from: data)

        XCTAssertEqual(decoded.nodes.count, 2)
        XCTAssertEqual(decoded.nodes.first?.effectType, .delay)
        XCTAssertEqual(decoded.nodes.first?.parameters[AUEffectParameterKey.delayTime], 0.5)
        // Enable/bypass state lives per node now that the chain has no flag of its own,
        // so that is where the round-trip has to be checked.
        XCTAssertEqual(decoded.nodes.first?.isEnabled, true)
        XCTAssertEqual(decoded.nodes.last?.isEnabled, false)
        XCTAssertEqual(decoded.activeNodes.count, 1)
    }

    func testPresetCodableRoundTrip() throws {
        let reverb = AUEffectNode(effectType: .reverb)
        let chain = AUEffectsChain(nodes: [reverb])
        let preset = AUEffectsPreset(name: "Test Preset", chain: chain)

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(AUEffectsPreset.self, from: data)

        XCTAssertEqual(decoded.name, "Test Preset")
        XCTAssertEqual(decoded.chain.nodes.count, 1)
    }
}
