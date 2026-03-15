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
    /// Returns a task that completes when the skin is loaded
    func loadSkin(forSystem systemId: SystemIdentifier, systemName: String = "Unknown") async -> (any DeltaSkinProtocol)? {
        ILOG("skins: DeltaSkinLoader starting to load skin for system: \(systemId.rawValue) (name: \(systemName))")

        await updateLoadingState(.loading)

        // Wrap the actual loading in a timeout to prevent hanging
        return await withTaskGroup(of: (any DeltaSkinProtocol)?.self) { group in
            // Start the actual load task
            group.addTask {
                do {
                    // Try to use already-loaded skins first (fast path)
                    let manager = DeltaSkinManager.shared

                    // Check if skins are already loaded — skinsAreLoaded is @MainActor,
                    // so hop to MainActor to read it safely.
                    let skinsAreLoaded = await MainActor.run { manager.skinsAreLoaded }
                    if skinsAreLoaded {
                        ILOG("skins: Skins already loaded, using fast path lookup")
                        // Fast path: use synchronous lookup from already-loaded skins
                        // Use effectiveSkinIdentifier to get session-aware selection
                        let orientation: SkinOrientation = .portrait // Default to portrait, could be made dynamic
                        if let selectedIdentifier = DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                            for: systemId,
                            gameId: nil,
                            orientation: orientation
                        ), let skin = await MainActor.run(body: { manager.loadedSkins.first(where: { $0.identifier == selectedIdentifier }) }) {
                            // Update UI state immediately but don't await - return skin right away
                            Task { @MainActor in
                                self.selectedSkin = skin
                                self.updateLoadingState(.complete)
                            }
                            ILOG("skins: Found selected skin '\(skin.name)' in cache for system \(systemId.rawValue)")
                            return skin
                        }

                        // Try default skin from cache
                        if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                           let skin = await MainActor.run(body: {
                               manager.loadedSkins.first(where: {
                                   $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                               })
                           }) {
                            // Update UI state immediately but don't await - return skin right away
                            Task { @MainActor in
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

                    // Fallback: async load (triggers scan if needed)
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
                        await self.updateLoadingState(.complete)
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

            // Start timeout task (only fires if skin loading takes too long)
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds max (increased from 2.5s)
                // Check if skin was found before timing out
                let skinFound = await MainActor.run {
                    self.selectedSkin != nil
                }
                if !skinFound {
                    WLOG("skins: Loading timeout (5s) - completing without skin for system \(systemId.rawValue)")
                    await MainActor.run {
                        self.updateLoadingState(.complete)
                    }
                }
                return nil
            }

            // Return first non-nil result (prioritize skin over timeout)
            // Use a loop to get the first non-nil result, or wait for timeout
            var result: (any DeltaSkinProtocol)? = nil
            for await value in group {
                if let skin = value {
                    // Found skin - return immediately and cancel timeout
                    result = skin
                    group.cancelAll()
                    return skin
                }
                // If we got nil from timeout, but haven't found a skin yet, continue waiting
                // The timeout task returns nil, so we need to check if skin task is still running
            }
            // If we get here, timeout fired and no skin was found
            group.cancelAll()
            return result
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
