import SwiftUI
import PVEmulatorCore
import PVLibrary

/// A simple wrapper view to avoid generic type inference issues
struct EmulatorWrapperView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore
    let onSkinLoaded: () -> Void
    let onRefreshRequested: () -> Void

    @ObservedObject var inputHandler: DeltaSkinInputHandler

    var body: some View {
        EmulatorWithSkinView(
            game: game,
            coreInstance: coreInstance,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested
        )
        .environmentObject(inputHandler)
        .ignoresSafeArea(.all)
    }
}
