import SwiftUI
import PVPrimitives

public extension View {
    /// Apply a Delta skin controller overlay to this view
    /// - Parameters:
    ///   - system: The system identifier
    ///   - traits: The skin traits to use
    ///   - onButtonPress: Callback when a button is pressed
    /// - Returns: A view with the controller overlay
    func deltaSkinController(
        for system: SystemIdentifier,
        traits: DeltaSkinTraits,
        onButtonPress: @escaping (String) -> Void
    ) -> some View {
        modifier(DeltaSkinControllerModifier(
            system: system,
            traits: traits,
            onButtonPress: onButtonPress
        ))
    }
}

/// View modifier that adds a Delta skin controller overlay
struct DeltaSkinControllerModifier: ViewModifier {
    let system: SystemIdentifier
    let traits: DeltaSkinTraits
    let onButtonPress: (String) -> Void

    @State private var skin: DeltaSkinProtocol?
    @State private var isLoading = true
    @State private var error: Error?

    func body(content: Content) -> some View {
        ZStack {
            // Base content
            content

            // Controller overlay
            if let skin = skin {
                DeltaSkinButtonsView(
                    skin: skin,
                    traits: traits,
                    onButtonPress: onButtonPress
                )
            }

            // Loading indicator
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            loadSkin()
        }
    }

    private func loadSkin() {
        Task {
            do {
                // Try to get the selected skin or default
                let skinToUse = try await DeltaSkinManager.shared.skinToUse(for: system)

                await MainActor.run {
                    self.skin = skinToUse
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
