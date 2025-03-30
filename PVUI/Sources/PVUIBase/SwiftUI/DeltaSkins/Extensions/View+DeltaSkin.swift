import SwiftUI
import PVPrimitives
import PVLogging

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
    
    /// Apply a Delta skin controller overlay to this view with automatic orientation handling
    /// - Parameters:
    ///   - system: The system identifier
    ///   - onButtonPress: Callback when a button is pressed
    /// - Returns: A view with the controller overlay
    func adaptiveDeltaSkinController(
        for system: SystemIdentifier,
        onButtonPress: @escaping (String) -> Void
    ) -> some View {
        modifier(AdaptiveDeltaSkinControllerModifier(
            system: system,
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
                // Get all skins for this system
                let allSkins = try await DeltaSkinManager.shared.skins(for: system)
                
                // Try to find the selected skin
                let selectedSkinId = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: system, orientation: traits.orientation)
                let selectedSkin = selectedSkinId.flatMap { id in allSkins.first { $0.identifier == id } }
                
                // Check if the selected skin supports the current traits
                let skinToUse: DeltaSkinProtocol?
                if let selectedSkin = selectedSkin, selectedSkin.supports(traits) {
                    skinToUse = selectedSkin
                    DLOG("Using selected skin: \(selectedSkin.name)")
                } else {
                    // Find a compatible skin
                    skinToUse = allSkins.first { $0.supports(traits) }
                    DLOG("Using compatible skin: \(skinToUse?.name ?? "none")")
                }

                await MainActor.run {
                    self.skin = skinToUse
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    ELOG("Error loading skin: \(error)")
                }
            }
        }
    }
}

/// View modifier that adds a Delta skin controller overlay with automatic orientation handling
struct AdaptiveDeltaSkinControllerModifier: ViewModifier {
    let system: SystemIdentifier
    let onButtonPress: (String) -> Void

    @State private var skin: DeltaSkinProtocol?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var currentOrientation: DeltaSkinOrientation = .portrait
    
    // Current device type for filtering
    private let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
    
    // Current traits based on device and orientation
    private var currentTraits: DeltaSkinTraits {
        DeltaSkinTraits(
            device: currentDevice,
            displayType: .standard,
            orientation: currentOrientation
        )
    }

    func body(content: Content) -> some View {
        ZStack {
            // Base content
            content

            // Controller overlay
            if let skin = skin {
                DeltaSkinButtonsView(
                    skin: skin,
                    traits: currentTraits,
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
            // Set initial orientation
            updateOrientation()
            loadSkin()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
            loadSkin()
        }
    }
    
    /// Update the current orientation based on device orientation
    private func updateOrientation() {
        let newOrientation: DeltaSkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        if newOrientation != currentOrientation {
            DLOG("Orientation changed to \(newOrientation)")
            currentOrientation = newOrientation
        }
    }

    private func loadSkin() {
        Task {
            do {
                // Use the new skinToUse method that handles orientation
                let skinToUse = try await DeltaSkinManager.shared.skinToUse(
                    for: system,
                    device: currentDevice,
                    orientation: currentOrientation
                )

                await MainActor.run {
                    self.skin = skinToUse
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    ELOG("Error loading skin: \(error)")
                }
            }
        }
    }
}
