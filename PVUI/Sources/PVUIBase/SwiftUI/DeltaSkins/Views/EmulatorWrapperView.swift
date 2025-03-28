import SwiftUI
import PVEmulatorCore
import PVLibrary

/// A simple wrapper view to avoid generic type inference issues
struct EmulatorWrapperView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore
    let onSkinLoaded: () -> Void
    let onRefreshRequested: () -> Void
    let onMenuRequested: () -> Void
    let showDebug: Bool

    @ObservedObject var inputHandler: DeltaSkinInputHandler

    init(
        game: PVGame,
        coreInstance: PVEmulatorCore,
        onSkinLoaded: @escaping () -> Void,
        onRefreshRequested: @escaping () -> Void,
        onMenuRequested: @escaping () -> Void,
        inputHandler: DeltaSkinInputHandler,
        showDebug: Bool = false
    ) {
        self.game = game
        self.coreInstance = coreInstance
        self.onSkinLoaded = onSkinLoaded
        self.onRefreshRequested = onRefreshRequested
        self.onMenuRequested = onMenuRequested
        self.inputHandler = inputHandler
        self.showDebug = showDebug
    }

    var body: some View {
        EmulatorWithSkinView(
            game: game,
            coreInstance: coreInstance,
            showDebugOverlay: showDebug,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested,
            onMenuRequested: onMenuRequested
        )
        .environmentObject(inputHandler)
        .ignoresSafeArea(.all)
        .overlay(
            // Debug overlay to show frame boundaries
            showDebug ?
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.yellow, lineWidth: 4)
                    .edgesIgnoringSafeArea(.all)
            : nil
        )
    }
}
