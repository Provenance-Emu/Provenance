import SwiftUI
import PVPrimitives

/// View for selecting a skin for a specific system
public struct SystemSkinSelectionView: View {
    let system: SystemIdentifier

    @StateObject private var skinManager = DeltaSkinManager.shared
    @StateObject private var preferences = DeltaSkinPreferences.shared

    @State private var availableSkins: [DeltaSkinProtocol] = []
    @State private var selectedSkinId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    public init(system: SystemIdentifier) {
        self.system = system
    }

    public var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if availableSkins.isEmpty {
                    noSkinsView
                } else {
                    skinGridView
                }
            }
            .navigationTitle("Select Controller Skin")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSkins()
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Loading skins...")
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Error loading skins")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                loadSkins()
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }

    private var noSkinsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Skins Available")
                .font(.headline)

            Text("There are no controller skins available for \(system.systemName).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Import Skin") {
                // Show skin import UI
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }

    private var skinGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                // Default option (system default)
                defaultSkinCell

                // Available skins
                ForEach(availableSkins, id: \.identifier) { skin in
                    skinCell(for: skin)
                }
            }
            .padding()
        }
    }

    private var defaultSkinCell: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(1.5, contentMode: .fit)

                Image(systemName: "gamecontroller")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedSkinId == nil ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            Text("System Default")
                .font(.caption)
                .lineLimit(1)
        }
        .onTapGesture {
            selectSkin(nil)
        }
    }

    private func skinCell(for skin: DeltaSkinProtocol) -> some View {
        VStack {
            ZStack {
                // Skin preview
                SkinPreviewImage(skin: skin)
                    .aspectRatio(1.5, contentMode: .fit)
                    .cornerRadius(12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedSkinId == skin.identifier ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            Text(skin.name)
                .font(.caption)
                .lineLimit(1)
        }
        .onTapGesture {
            selectSkin(skin.identifier)
        }
        .contextMenu {
            Button {
                selectSkin(skin.identifier)
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }

            if skinManager.isDeletable(skin) {
                Button(role: .destructive) {
                    deleteSkin(skin)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func loadSkins() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Load skins for this system
                let skins = try await skinManager.skins(for: system)

                // Get currently selected skin
                let currentSelection = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: system)

                // Update UI on main thread
                await MainActor.run {
                    self.availableSkins = skins
                    self.selectedSkinId = currentSelection
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func selectSkin(_ identifier: String?) {
        Task {
            await DeltaSkinPreferences.shared.setSelectedSkin(identifier, for: system)
            await MainActor.run {
                self.selectedSkinId = identifier
            }
        }
    }

    private func deleteSkin(_ skin: DeltaSkinProtocol) {
        Task {
            do {
                try await skinManager.deleteSkin(skin.identifier)

                // If we deleted the selected skin, reset selection
                if selectedSkinId == skin.identifier {
                    await DeltaSkinPreferences.shared.setSelectedSkin(nil, for: system)
                }

                // Reload skins
                loadSkins()
            } catch {
                print("Error deleting skin: \(error)")
            }
        }
    }
}

/// Helper view to display a skin preview image
struct SkinPreviewImage: View {
    let skin: DeltaSkinProtocol

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
            }
        }
        .onAppear {
            loadPreview()
        }
    }

    private func loadPreview() {
        Task {
            do {
                // Use portrait orientation for preview
                let traits = DeltaSkinTraits(
                    device: .iphone,
                    displayType: .standard,
                    orientation: .portrait
                )

                // Try to load the image
                let skinImage = try await skin.image(for: traits)

                await MainActor.run {
                    self.image = skinImage
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
