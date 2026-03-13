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

    /// Observable state for virtual keyboard/mouse overlays.  Injected as an
    /// environment object so `VirtualInputToggleOverlayView` and any other child
    /// can subscribe without a direct view-controller reference.
    /// Nil on platforms where virtual input overlays are unavailable.
    var virtualInputState: VirtualInputState?

    var body: some View {
        if let state = virtualInputState {
            EmulatorWithSkinView(
                game: game,
                coreInstance: coreInstance,
                onSkinLoaded: onSkinLoaded,
                onRefreshRequested: onRefreshRequested,
                preselectedSkinIdentifier: preselectedSkinIdentifier
            )
            .environmentObject(inputHandler)
            .environmentObject(state)
            .ignoresSafeArea(.all)
        } else {
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
}
