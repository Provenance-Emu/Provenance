import Foundation
import Combine
import PVLibrary
import PVLogging

/// A class responsible for loading Delta skins with progress tracking
class DeltaSkinLoader: ObservableObject {
    // Published properties for UI updates
    @Published var isLoading = true
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: LoadingStage = .initializing
    @Published var selectedSkin: DeltaSkinProtocol?
    @Published var loadingError: Error?

    // Loading stages for better progress reporting
    enum LoadingStage: String, CaseIterable {
        case initializing = "Initializing..."
        case loadingSkin = "Loading skin..."
        case processingAssets = "Processing assets..."
        case renderingLayout = "Rendering layout..."
        case finalizing = "Finalizing..."
        case complete = "Complete"

        var progressValue: Double {
            switch self {
            case .initializing: return 0.1
            case .loadingSkin: return 0.3
            case .processingAssets: return 0.5
            case .renderingLayout: return 0.7
            case .finalizing: return 0.9
            case .complete: return 1.0
            }
        }
    }

    /// Load a skin for the given game
    /// Returns a task that completes when the skin is loaded
    func loadSkin(for game: PVGame) async -> DeltaSkinProtocol? {
        DLOG("🎮 DeltaSkinLoader: Starting to load Delta Skin for \(game.title)")

        // Start with initializing stage
        await updateLoadingState(.initializing)

        do {
            // Move to loading skin stage
            await updateLoadingState(.loadingSkin)

            // Load the skin
            if let systemId = game.system?.systemIdentifier {
                if let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                    // Move to processing assets stage
                    await updateLoadingState(.processingAssets)

                    // Simulate asset processing time (in a real implementation, this would be actual processing)
                    try await Task.sleep(nanoseconds: 200_000_000)

                    // Move to rendering layout stage
                    await updateLoadingState(.renderingLayout)

                    // Set the skin and prepare for display
                    await MainActor.run {
                        // Store the skin
                        self.selectedSkin = skin

                        // Move to finalizing stage
                        self.updateLoadingState(.finalizing)
                    }

                    // Wait a moment to ensure UI updates
                    try await Task.sleep(nanoseconds: 300_000_000)

                    // Complete loading
                    await updateLoadingState(.complete)

                    DLOG("🎮 DeltaSkinLoader: Skin loaded for \(game.title)")
                    return skin
                } else {
                    ELOG("🎮 DeltaSkinLoader: No skin available for system: \(systemId)")
                    await updateLoadingState(.complete)
                    return nil
                }
            } else {
                ELOG("🎮 DeltaSkinLoader: No system identifier available for game: \(game.title)")
                await updateLoadingState(.complete)
                return nil
            }
        } catch {
            ELOG("🎮 DeltaSkinLoader: Error loading skin: \(error)")
            await MainActor.run {
                self.loadingError = error
            }
            await updateLoadingState(.complete)
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

        DLOG("🎮 DeltaSkinLoader: Loading stage: \(stage.rawValue) (\(Int(loadingProgress * 100))%)")
    }
}
