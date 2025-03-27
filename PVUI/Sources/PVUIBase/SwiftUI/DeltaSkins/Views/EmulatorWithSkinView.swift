import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVSystems

/// A SwiftUI view that displays a custom skin for the emulator
struct EmulatorWithSkinView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore

    // State for the skin
    @State private var selectedSkin: DeltaSkin?
    @State private var isLoading = true
    @State private var asyncSkin: DeltaSkinProtocol?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)

                if let skin = selectedSkin {
                    // If we have a skin, use DeltaSkinScreensView
                    DeltaSkinScreensView(
                        skin: skin,
                        traits: .init(device: .iphone,
                                      displayType: .edgeToEdge,
                                      orientation: .portrait,
                                      iPadModel: nil,
                                      externalDisplay: .none),
                        containerSize: geometry.size
                    )
                } else if let asyncSkin = asyncSkin {
                    // If we have an async skin, use DeltaSkinScreensView
                    DeltaSkinScreensView(
                        skin: asyncSkin,
                        traits: .init(device: .iphone,
                                      displayType: .edgeToEdge,
                                      orientation: .portrait,
                                      iPadModel: nil,
                                      externalDisplay: .none),
                        containerSize: geometry.size
                    )
                } else if isLoading {
                    // Loading indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .foregroundColor(.white)
                } else {
                    // Fallback controller
                    defaultControllerSkin()
                }
            }
            .onAppear {
                // Try to load a skin when the view appears
                Task {
                    await loadSkin()
                }
            }
        }
    }

    /// Load a skin for the current game
    private func loadSkin() async {
        isLoading = true

        // Get the system identifier
        if let systemId = game.system?.systemIdentifier {
            print("Loading skin for system: \(systemId)")

            // Try to get a skin from the manager using our new synchronous method
            selectedSkin = await DeltaSkinManager.shared.skin(for: systemId)

            if selectedSkin != nil {
                print("Successfully loaded skin for \(systemId): \(selectedSkin!.name)")
                isLoading = false
            } else {
                print("No skin available from sync method for \(systemId)")

                // Try to get all skins for this system synchronously
                let systemSkins = await DeltaSkinManager.shared.availableSkinsSync(for: systemId)
                print("Available skins (sync): \(systemSkins.count)")

                // If there are any skins, use the first one
                if let firstSkin = systemSkins.first {
                    selectedSkin = firstSkin
                    print("Using first available skin (sync): \(firstSkin.name)")
                    isLoading = false
                } else {
                    // Try to get a skin asynchronously
                    Task {
                        do {
                            // Try to get the skin to use
                            asyncSkin = try await DeltaSkinManager.shared.skinToUse(for: systemId)

                            if asyncSkin != nil {
                                print("Loaded async skin for \(systemId): \(asyncSkin!.identifier)")
                            } else {
                                print("No async skin available for \(systemId)")

                                // Try to get all skins for this system
                                let systemSkins = try await DeltaSkinManager.shared.availableSkins(for: systemId)
                                print("Available skins (async): \(systemSkins.count)")

                                // If there are any skins, use the first one
                                if let firstSkin = systemSkins.first {
                                    await MainActor.run {
                                        selectedSkin = firstSkin as? DeltaSkin
                                    }
                                    print("Using first available skin (async): \(firstSkin.identifier)")
                                }
                            }
                        } catch {
                            print("Error loading async skin: \(error)")
                        }

                        // Update loading state on the main thread
                        await MainActor.run {
                            isLoading = false
                        }
                    }
                }
            }
        } else {
            print("No system identifier available for game: \(game.title)")
            isLoading = false
        }
    }

    /// Default controller skin as a fallback
    private func defaultControllerSkin() -> some View {
        VStack(spacing: 20) {
            // D-Pad
            dPadView()

            // Action buttons
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    circleButton(label: "Y", color: .yellow)
                    circleButton(label: "X", color: .blue)
                }

                VStack(spacing: 10) {
                    circleButton(label: "B", color: .red)
                    circleButton(label: "A", color: .green)
                }
            }

            // Start/Select buttons
            HStack(spacing: 20) {
                pillButton(label: "SELECT", color: .black)
                pillButton(label: "START", color: .black)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.5))
        .cornerRadius(20)
    }

    /// D-Pad view
    private func dPadView() -> some View {
        VStack(spacing: 0) {
            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }

            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)

                Button(action: {}) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }

            Button(action: {}) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }

    /// Circle button view
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
    }

    /// Pill-shaped button view
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 30)
                .background(color)
                .cornerRadius(15)
        }
    }
}
