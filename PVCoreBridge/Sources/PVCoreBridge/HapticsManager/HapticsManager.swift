//
//  HapticsManager.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/3/24.
//

import Foundation
import GameController
import CoreHaptics

@MainActor
@available(iOS 14.0, tvOS 14.0, *)
internal final class HapticsManager: Sendable {

    static let shared: HapticsManager = .init()
    static private func buildEngine() -> CHHapticEngine {
        let engine = try! CHHapticEngine.init()
        engine.isAutoShutdownEnabled = true
        engine.isMutedForAudio = false
        engine.isMutedForHaptics = true
        return engine
    }

    static private func buildEngine(forController controller: GCController) -> CHHapticEngine {
        let newEngine = controller.haptics?.createEngine(withLocality: GCHapticsLocality.all) ?? HapticsManager.buildEngine()
        newEngine.isAutoShutdownEnabled = true
        return newEngine
    }

    private let hapticEngines: [CHHapticEngine]

    private init() {
        hapticEngines = [
            HapticsManager.buildEngine(),
            HapticsManager.buildEngine(),
            HapticsManager.buildEngine(),
            HapticsManager.buildEngine()
        ]

    }

    func hapticsEngine(forPlayer player: Int) async -> CHHapticEngine? {
        guard player < hapticEngines.count else { return nil }
        let engine = hapticEngines[player]
        return engine
    }
}
