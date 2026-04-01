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
    /// Fires once packaged vs programmatic skin resolution completes (initial load path).
    let onInitialSkinResolutionComplete: (() -> Void)?

    @ObservedObject var inputHandler: DeltaSkinInputHandler

    /// Observable state for virtual keyboard/mouse overlays.  Injected as an
    /// environment object so `VirtualInputToggleOverlayView` and any other child
    /// can subscribe without a direct view-controller reference.
    /// Nil on platforms where virtual input overlays are unavailable.
    var virtualInputState: VirtualInputState?

    /// Explicit initializer — required because `@ObservedObject` + defaulted `let` fields do not produce a reliable memberwise `init` for all call sites.
    init(
        game: PVGame,
        coreInstance: PVEmulatorCore,
        onSkinLoaded: @escaping () -> Void,
        onRefreshRequested: @escaping () -> Void,
        preselectedSkinIdentifier: String?,
        onInitialSkinResolutionComplete: (() -> Void)? = nil,
        inputHandler: DeltaSkinInputHandler,
        virtualInputState: VirtualInputState? = nil
    ) {
        self.game = game
        self.coreInstance = coreInstance
        self.onSkinLoaded = onSkinLoaded
        self.onRefreshRequested = onRefreshRequested
        self.preselectedSkinIdentifier = preselectedSkinIdentifier
        self.onInitialSkinResolutionComplete = onInitialSkinResolutionComplete
        _inputHandler = ObservedObject(wrappedValue: inputHandler)
        self.virtualInputState = virtualInputState
    }

    var body: some View {
        if let state = virtualInputState {
            EmulatorWithSkinView(
                game: game,
                coreInstance: coreInstance,
                onSkinLoaded: onSkinLoaded,
                onRefreshRequested: onRefreshRequested,
                preselectedSkinIdentifier: preselectedSkinIdentifier,
                onInitialSkinResolutionComplete: onInitialSkinResolutionComplete
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
                preselectedSkinIdentifier: preselectedSkinIdentifier,
                onInitialSkinResolutionComplete: onInitialSkinResolutionComplete
            )
            .environmentObject(inputHandler)
            .ignoresSafeArea(.all)
        }
    }
}
