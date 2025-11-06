import SwiftUI
import PVEmulatorCore
import PVLibrary

/// A simple wrapper view to avoid generic type inference issues
struct EmulatorWrapperView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore
    let onSkinLoaded: () -> Void
    let onRefreshRequested: () -> Void
    /// Optional override of the skin identifier to display immediately for this session
    let preselectedSkinIdentifier: String?

    @ObservedObject var inputHandler: DeltaSkinInputHandler

    var body: some View {
        EmulatorWithSkinView(
            game: game,
            coreInstance: coreInstance,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested,
            preselectedSkinIdentifier: preselectedSkinIdentifier
        )
        .environmentObject(inputHandler)
        .ignoresSafeArea(.all)
    }
}
