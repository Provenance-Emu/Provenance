import SwiftUI
import PVPrimitives

/// Shows a preview of the selected skins for a system in both portrait and landscape orientations with retrowave styling
struct SystemSkinPreviewRow: View {
    // MARK: - Properties

    let system: SystemIdentifier

    @ObservedObject private var skinManager = DeltaSkinManager.shared
    @ObservedObject private var selectionManager = DeltaSkinSelectionManager.shared

    @State private var portraitSkin: (any DeltaSkinProtocol)?
    @State private var landscapeSkin: (any DeltaSkinProtocol)?
    @State private var isLoading = true

    // Animation properties
    @State private var glowIntensity: CGFloat = 0.5

    /// Device type used to resolve which skin representations to preview.
    private var currentDevice: DeltaSkinDevice {
        #if os(tvOS)
        return .ipad
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                loadingView
            } else {
                HStack(spacing: 16) {
                    orientationPreview(
                        orientation: .portrait,
                        skin: portraitSkin,
                        title: "PORTRAIT"
                    )

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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
            loadSelectedSkins()
        }
        .onChange(of: skinManager.skinsAreLoaded) { loaded in
            if loaded {
                loadSelectedSkins()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DeltaSkinSelectionManager.selectionChangedNotification)) { _ in
            loadSelectedSkins()
        }
    }

    // MARK: - UI Components

    private var loadingView: some View {
        HStack {
            Spacer()

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
        let isLandscape = orientation == .landscape

        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: orientation.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(RetroTheme.retroHorizontalGradient)
            .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.3), radius: 1)

            ZStack {
                if let skin {
                    SkinSelectionPreviewCell(
                        skin: skin,
                        manager: skinManager,
                        orientation: orientation.deltaSkinOrientation
                    )
                    .id("\(skin.identifier)-\(orientation.rawValue)")
                    .aspectRatio(isLandscape ? 2.0 : 0.5, contentMode: .fit)
                    .frame(maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                            .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 2)
                    )
                } else {
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
                    .aspectRatio(isLandscape ? 2.0 : 0.5, contentMode: .fit)
                    .frame(maxHeight: 100)
                    .background(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Handling

    /// Whether a skin supports the given orientation on the current device.
    private func skinSupportsOrientation(_ skin: DeltaSkinProtocol, orientation: SkinOrientation) -> Bool {
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        for display in displayTypes {
            let traits = DeltaSkinTraits(
                device: currentDevice,
                displayType: display,
                orientation: orientation.deltaSkinOrientation
            )
            if skin.supports(traits) { return true }
        }
        return false
    }

    /// Resolves the skin to preview: explicit selection first, then first compatible system skin.
    private func resolvePreviewSkin(
        for orientation: SkinOrientation,
        from systemSkins: [DeltaSkinProtocol]
    ) -> (any DeltaSkinProtocol)? {
        if let skinId = selectionManager.effectiveSkinIdentifier(for: system, gameId: nil, orientation: orientation),
           let skin = systemSkins.first(where: { $0.identifier == skinId }),
           skinSupportsOrientation(skin, orientation: orientation) {
            return skin
        }

        return systemSkins.first { skin in
            skinSupportsOrientation(skin, orientation: orientation)
                && CaseControllerDetector.isAllowedInAutomaticSkinSelection(skin.identifier)
        }
    }

    private func loadSelectedSkins() {
        Task {
            await MainActor.run {
                isLoading = true
            }

            do {
                let systemSkins = try await skinManager.skins(for: system)
                let portraitSkinObj = resolvePreviewSkin(for: .portrait, from: systemSkins)
                let landscapeSkinObj = resolvePreviewSkin(for: .landscape, from: systemSkins)

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.portraitSkin = portraitSkinObj
                        self.landscapeSkin = landscapeSkinObj
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
