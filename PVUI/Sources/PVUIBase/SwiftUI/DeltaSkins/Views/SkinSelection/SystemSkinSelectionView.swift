import SwiftUI
import PVPrimitives

/// View for selecting a skin for a specific system
public struct SystemSkinSelectionView: View {
    let system: SystemIdentifier

    @StateObject private var skinManager = DeltaSkinManager.shared
    @StateObject private var preferences = DeltaSkinPreferences.shared

    @State private var availableSkins: [DeltaSkinProtocol] = []
    @State private var portraitSkins: [DeltaSkinProtocol] = []
    @State private var landscapeSkins: [DeltaSkinProtocol] = []
    @State private var selectedSkinId: String?
    @State private var selectedPortraitSkinId: String?
    @State private var selectedLandscapeSkinId: String?
    @State private var selectedOrientation: SkinOrientation = .portrait
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
                    VStack(spacing: 0) {
                        // Orientation picker
                        Picker("Orientation", selection: $selectedOrientation) {
                            ForEach(SkinOrientation.allCases, id: \.self) { orientation in
                                Label(orientation.displayName, systemImage: orientation.icon)
                                    .tag(orientation)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Skin grid for selected orientation
                        skinGridView
                    }
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
            VStack(alignment: .leading, spacing: 8) {
                // Show current selection status
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text(selectedOrientation == .portrait ? 
                         "Selected skin will be used in portrait mode" : 
                         "Selected skin will be used in landscape mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                    // Default option (system default)
                    defaultSkinCell
                    
                    // Available skins for the selected orientation
                    let filteredSkins = selectedOrientation == .portrait ? portraitSkins : landscapeSkins
                    ForEach(filteredSkins, id: \.identifier) { skin in
                        skinCell(for: skin)
                    }
                }
                .padding()
            }
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
                    .stroke(currentSelectedSkinId == nil ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            Text("System Default")
                .font(.caption)
                .lineLimit(1)
        }
        .onTapGesture {
            selectSkin(nil)
        }
    }
    
    // Helper property to get the current selected skin ID based on orientation
    private var currentSelectedSkinId: String? {
        selectedOrientation == .portrait ? selectedPortraitSkinId : selectedLandscapeSkinId
    }

    private func skinCell(for skin: DeltaSkinProtocol) -> some View {
        VStack {
            ZStack {
                // Skin preview with correct orientation
                SkinPreviewCell(skin: skin, manager: skinManager, orientation: selectedOrientation.deltaSkinOrientation)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(currentSelectedSkinId == skin.identifier ? Color.accentColor : Color.clear, lineWidth: 3)
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
            
            Button {
                // Select for both orientations
                Task {
                    await preferences.setSelectedSkin(skin.identifier, for: system, orientation: .portrait)
                    await preferences.setSelectedSkin(skin.identifier, for: system, orientation: .landscape)
                    await MainActor.run {
                        self.selectedPortraitSkinId = skin.identifier
                        self.selectedLandscapeSkinId = skin.identifier
                    }
                }
            } label: {
                Label("Use for Both Orientations", systemImage: "rectangle.portrait.and.landscape")
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
                // Load all skins for this system
                let skins = try await skinManager.skins(for: system)
                
                // Filter skins by orientation support
                var portraitCompatible: [DeltaSkinProtocol] = []
                var landscapeCompatible: [DeltaSkinProtocol] = []
                
                for skin in skins {
                    // Check portrait support
                    let portraitTraits = DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait)
                    if skin.supports(portraitTraits) {
                        portraitCompatible.append(skin)
                    }
                    
                    // Check landscape support
                    let landscapeTraits = DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .landscape)
                    if skin.supports(landscapeTraits) {
                        landscapeCompatible.append(skin)
                    }
                }

                // Get currently selected skins for both orientations
                let portraitSelection = preferences.selectedSkinIdentifier(for: system, orientation: .portrait)
                let landscapeSelection = preferences.selectedSkinIdentifier(for: system, orientation: .landscape)

                // Update UI on main thread
                await MainActor.run {
                    self.availableSkins = skins
                    self.portraitSkins = portraitCompatible
                    self.landscapeSkins = landscapeCompatible
                    self.selectedPortraitSkinId = portraitSelection
                    self.selectedLandscapeSkinId = landscapeSelection
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
            // Set the skin for the current orientation only
            await preferences.setSelectedSkin(identifier, for: system, orientation: selectedOrientation)
            
            // Update the appropriate state variable
            await MainActor.run {
                if selectedOrientation == .portrait {
                    self.selectedPortraitSkinId = identifier
                } else {
                    self.selectedLandscapeSkinId = identifier
                }
            }
        }
    }

    private func deleteSkin(_ skin: DeltaSkinProtocol) {
        Task {
            do {
                try await skinManager.deleteSkin(skin.identifier)

                // If we deleted a selected skin, reset the appropriate selection(s)
                if selectedPortraitSkinId == skin.identifier {
                    await preferences.setSelectedSkin(nil, for: system, orientation: .portrait)
                }
                
                if selectedLandscapeSkinId == skin.identifier {
                    await preferences.setSelectedSkin(nil, for: system, orientation: .landscape)
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
