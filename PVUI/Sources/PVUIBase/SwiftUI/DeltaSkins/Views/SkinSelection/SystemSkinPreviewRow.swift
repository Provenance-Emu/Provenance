import SwiftUI
import PVPrimitives

/// Shows a preview of the selected skins for a system in both portrait and landscape orientations with retrowave styling
struct SystemSkinPreviewRow: View {
    // MARK: - Properties

    let system: SystemIdentifier

    @StateObject private var skinManager = DeltaSkinManager.shared
    @StateObject private var preferences = DeltaSkinPreferences.shared

    @State private var portraitSkin: (any DeltaSkinProtocol)? = nil
    @State private var landscapeSkin: (any DeltaSkinProtocol)? = nil
    @State private var isLoading = true

    // Animation properties
    @State private var glowIntensity: CGFloat = 0.5
    @State private var isHovering = false
    @State private var loadingProgress: Double = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                loadingView
            } else {
                HStack(spacing: 16) {
                    // Portrait skin preview
                    orientationPreview(
                        orientation: .portrait,
                        skin: portraitSkin,
                        title: "PORTRAIT"
                    )

                    // Landscape skin preview
                    orientationPreview(
                        orientation: .landscape,
                        skin: landscapeSkin,
                        title: "LANDSCAPE"
                    )
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            // Start glow animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }

            // Load skins with a slight delay for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                loadSelectedSkins()
            }
        }
    }

    // MARK: - UI Components

    private var loadingView: some View {
        HStack {
            Spacer()

            // Retrowave styled loading indicator
            ZStack {
                Circle()
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        lineWidth: 2
                    )
                    .frame(width: 40, height: 40)
                    .blur(radius: 1 * glowIntensity)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(360 * glowIntensity))
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2)
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            glowIntensity = 1.0
                        }
                    }
            }

            Spacer()
        }
        .frame(height: 100)
    }

    private func orientationPreview(orientation: SkinOrientation, skin: (any DeltaSkinProtocol)?, title: String) -> some View {
        VStack(spacing: 6) {
            // Title with orientation
            HStack(spacing: 4) {
                Image(systemName: orientation.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(RetroTheme.retroHorizontalGradient)
            .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.3), radius: 1)

            // Skin preview or placeholder
            ZStack {
                if let skin = skin {
                    // Show actual skin preview with retrowave styling
                    SkinSelectionPreviewCell(
                        skin: skin,
                        manager: skinManager,
                        orientation: orientation.deltaSkinOrientation
                    )
                    .frame(height: 100)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                            .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 2)
                    )
                } else {
                    // Show default placeholder with retrowave styling
                    VStack(spacing: 8) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 24))
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                            .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 2)

                        Text("DEFAULT")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Handling

    private func loadSelectedSkins() {
        Task {
            isLoading = true

            // Add a small delay for animation
            try? await Task.sleep(nanoseconds: 300_000_000)

            do {
                // Get selected skin IDs
                let portraitSkinId = preferences.selectedSkinIdentifier(for: system, orientation: .portrait)
                let landscapeSkinId = preferences.selectedSkinIdentifier(for: system, orientation: .landscape)

                // Load all skins once and reuse (use cached loadedSkins if available)
                let allSkins = skinManager.loadedSkins.isEmpty
                    ? (try? await skinManager.availableSkins()) ?? []
                    : skinManager.loadedSkins

                // Find skins by their identifiers
                let portraitSkinObj = portraitSkinId.flatMap { id in
                    allSkins.first(where: { $0.identifier == id })
                }

                let landscapeSkinObj = landscapeSkinId.flatMap { id in
                    allSkins.first(where: { $0.identifier == id })
                }

                // Update UI with animation
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.portraitSkin = portraitSkinObj
                        self.landscapeSkin = landscapeSkinObj
                        self.isLoading = false
                    }
                }
            } catch {
                // Handle errors gracefully
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
