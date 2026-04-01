import Foundation
import Combine
import PVLibrary
import PVLogging
import PVSystems

/// A class responsible for loading Delta skins with progress tracking
class DeltaSkinLoader: ObservableObject {
    // Published properties for UI updates
    @Published var isLoading = true
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: LoadingStage = .loading
    @Published var selectedSkin: (any DeltaSkinProtocol)?
    @Published var loadingError: Error?

    // Loading stages for better progress reporting
    enum LoadingStage: String, CaseIterable {
        case loading = "Loading skin..."
        case complete = "Complete"

        var progressValue: Double {
            switch self {
            case .loading: return 0.5
            case .complete: return 1.0
            }
        }
    }

    /// Load a skin for the given system identifier
    /// Returns when the skin is resolved or no skin is available (no arbitrary timeout).
    func loadSkin(forSystem systemId: SystemIdentifier, systemName: String = "Unknown") async -> (any DeltaSkinProtocol)? {
        ILOG("skins: DeltaSkinLoader starting to load skin for system: \(systemId.rawValue) (name: \(systemName))")

        await MainActor.run { self.updateLoadingState(.loading) }

        do {
            let manager = DeltaSkinManager.shared

            let skinsAreLoaded = await MainActor.run { manager.skinsAreLoaded }
            if skinsAreLoaded {
                ILOG("skins: Skins already loaded, using fast path lookup")
                let orientation: SkinOrientation = .portrait
                if let selectedIdentifier = DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                    for: systemId,
                    gameId: nil,
                    orientation: orientation
                ), let skin = await MainActor.run(body: { manager.loadedSkins.first(where: { $0.identifier == selectedIdentifier }) }) {
                    await MainActor.run {
                        self.selectedSkin = skin
                        self.updateLoadingState(.complete)
                    }
                    ILOG("skins: Found selected skin '\(skin.name)' in cache for system \(systemId.rawValue)")
                    return skin
                }

                if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                   let skin = await MainActor.run(body: {
                       manager.loadedSkins.first(where: {
                           let matchesType = $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                           guard matchesType else { return false }
                           return CaseControllerDetector.isAllowedInAutomaticSkinSelection($0.identifier)
                       })
                   }) {
                    await MainActor.run {
                        self.selectedSkin = skin
                        self.updateLoadingState(.complete)
                    }
                    ILOG("skins: Found default skin '\(skin.name)' in cache for system \(systemId.rawValue)")
                    return skin
                }
                WLOG("skins: No skin found in cache for system \(systemId.rawValue), falling back to async load")
            } else {
                ILOG("skins: Skins not loaded yet, will trigger async load")
            }

            ILOG("skins: Attempting async load of skin for system \(systemId.rawValue)")
            if let skin = try await manager.skinToUse(for: systemId) {
                await MainActor.run {
                    self.selectedSkin = skin
                    self.updateLoadingState(.complete)
                }
                ILOG("skins: Successfully loaded skin '\(skin.name)' for system \(systemId.rawValue)")
                return skin
            } else {
                WLOG("skins: No skin available for system: \(systemId.rawValue)")
                await MainActor.run { self.updateLoadingState(.complete) }
                return nil
            }
        } catch {
            ELOG("skins: Error loading skin for system \(systemId.rawValue): \(error)")
            await MainActor.run {
                self.loadingError = error
                self.updateLoadingState(.complete)
            }
            return nil
        }
    }

    /// Update the loading state with the new stage
    @MainActor
    private func updateLoadingState(_ stage: LoadingStage) {
        loadingStage = stage
        loadingProgress = stage.progressValue

        // When complete, set isLoading to false
        if stage == .complete {
            isLoading = false
        }

        ILOG("skins: DeltaSkinLoader loading stage: \(stage.rawValue) (\(Int(loadingProgress * 100))%)")
    }
}
