import SwiftUI
import PVPrimitives

/// Shows a preview of the selected skins for a system in both portrait and landscape orientations
struct SystemSkinPreviewRow: View {
    let system: SystemIdentifier
    
    @StateObject private var skinManager = DeltaSkinManager.shared
    @StateObject private var preferences = DeltaSkinPreferences.shared
    
    @State private var portraitSkin: (any DeltaSkinProtocol)? = nil
    @State private var landscapeSkin: (any DeltaSkinProtocol)? = nil
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(height: 100)
            } else {
                HStack(spacing: 16) {
                    // Portrait skin preview
                    orientationPreview(
                        orientation: .portrait,
                        skin: portraitSkin,
                        title: "Portrait"
                    )
                    
                    // Landscape skin preview
                    orientationPreview(
                        orientation: .landscape,
                        skin: landscapeSkin,
                        title: "Landscape"
                    )
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadSelectedSkins()
        }
    }
    
    private func orientationPreview(orientation: SkinOrientation, skin: (any DeltaSkinProtocol)?, title: String) -> some View {
        VStack(spacing: 4) {
            // Title with orientation
            HStack {
                Image(systemName: orientation.icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.secondary)
            
            // Skin preview or placeholder
            ZStack {
                if let skin = skin {
                    // Show actual skin preview
                    SkinPreviewCell(
                        skin: skin,
                        manager: skinManager,
                        orientation: orientation.deltaSkinOrientation
                    )
                    .frame(height: 100)
                    .cornerRadius(8)
                } else {
                    // Show default placeholder
                    VStack {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("Default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func loadSelectedSkins() {
        Task {
            isLoading = true
            
            // Get selected skin IDs
            let portraitSkinId = preferences.selectedSkinIdentifier(for: system, orientation: .portrait)
            let landscapeSkinId = preferences.selectedSkinIdentifier(for: system, orientation: .landscape)
            
            // Load actual skin objects
            var portraitSkinObj: (any DeltaSkinProtocol)? = nil
            var landscapeSkinObj: (any DeltaSkinProtocol)? = nil
            
            if let portraitSkinId = portraitSkinId {
                // Find the skin by its identifier in the loaded skins
                portraitSkinObj = await try? skinManager.availableSkins().first(where: { $0.identifier == portraitSkinId })
            }
            
            if let landscapeSkinId = landscapeSkinId {
                // Find the skin by its identifier in the loaded skins
                landscapeSkinObj = await try? skinManager.availableSkins().first(where: { $0.identifier == landscapeSkinId })
            }
            
            // Update UI
            await MainActor.run {
                self.portraitSkin = portraitSkinObj
                self.landscapeSkin = landscapeSkinObj
                self.isLoading = false
            }
        }
    }
}
