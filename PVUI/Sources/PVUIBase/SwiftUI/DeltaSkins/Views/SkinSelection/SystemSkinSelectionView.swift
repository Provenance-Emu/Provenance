import SwiftUI
import PVPrimitives
import PVLogging
import UniformTypeIdentifiers

/// View for selecting a skin for a specific system
public struct SystemSkinSelectionView: View {
    let system: SystemIdentifier

    @StateObject private var skinManager = DeltaSkinManager.shared
    @StateObject private var preferences = DeltaSkinPreferences.shared

    @State private var availableSkins: [DeltaSkinProtocol] = []
    @State private var filteredSkins: [DeltaSkinProtocol] = []
    @State private var selectedPortraitSkinId: String?
    @State private var selectedLandscapeSkinId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentOrientation: DeltaSkinOrientation = .portrait
    
    // Current device type for filtering
    private let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone

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
                } else if filteredSkins.isEmpty {
                    noSkinsView
                } else {
                    VStack(spacing: 0) {
                        // Orientation picker
                        Picker("Orientation", selection: $currentOrientation) {
                            Text("Portrait").tag(DeltaSkinOrientation.portrait)
                            Text("Landscape").tag(DeltaSkinOrientation.landscape)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        .onChange(of: currentOrientation) { newOrientation in
                            updateSelectedSkinId()
                            filterSkins()
                        }
                        
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

    // Dynamic grid sizing based on size class
    private var columns: [GridItem] {
        let minWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 200 : 160
        return [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
    }
    
    private var skinGridView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Default option (system default)
                defaultSkinCell
                    .padding(.horizontal)
                
                // Divider with label
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    Text("Available Skins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .padding(.horizontal)
                
                // Available skins grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredSkins, id: \.identifier) { skin in
                        skinCell(for: skin)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.systemGroupedBackground)
    }

    private var defaultSkinCell: some View {
        Button {
            selectSkin(nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 60, height: 60)

                    Image(systemName: "gamecontroller")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Default")
                        .font(.headline)
                    
                    Text("Use the system's built-in controller layout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if currentSelectedSkinId == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondarySystemGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(currentSelectedSkinId == nil ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @State private var showingShareSheet = false
    @State private var skinToShare: DeltaSkinProtocol? = nil
    
    private func skinCell(for skin: DeltaSkinProtocol) -> some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Preview
                PreviewContainer {
                    EnhancedSkinPreview(skin: skin, orientation: currentOrientation, device: currentDevice)
                        .allowsHitTesting(false)
                }
                .overlay {
                    // Rubber-like gradient overlay
                    LinearGradient(
                        colors: [
                            .black.opacity(0.4),
                            .clear,
                            .black.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(skin.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack {
                        Label(system.fullName, systemImage: "gamecontroller")
                            .lineLimit(1)

                        Spacer()
                        
                        // Selection indicator
                        if currentSelectedSkinId == skin.identifier {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(
                ZStack {
                    // Base rubber texture
                    UIColor.systemBackground == .white ? Color.white : Color(white: 0.15)

                    // Noise texture overlay for rubber effect
                    Color.black
                        .opacity(0.05)
                        .blendMode(.overlay)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                // Embossed edge effect
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(white: UIColor.systemBackground == .white ? 0.7 : 0), lineWidth: 2)
                    .blur(radius: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 2)
                    )
                    .blendMode(.overlay)
            }
            .overlay {
                // Selection indicator
                RoundedRectangle(cornerRadius: 16)
                    .stroke(currentSelectedSkinId == skin.identifier ? Color.accentColor : Color.clear, lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            .padding(2)
            
            // Transparent overlay to capture taps and context menu
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selectSkin(skin.identifier)
                }
        }
        .contextMenu {
            Button {
                selectSkin(skin.identifier)
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }
            
            Button {
                skinToShare = skin
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            if skinManager.isDeletable(skin) {
                Button(role: .destructive) {
                    deleteSkin(skin)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: { skinToShare = nil }) {
            if let skinToShare = skinToShare {
                ShareSheet(activityItems: [skinToShare.fileURL])
            }
        }
    }

    private func loadSkins() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // First, try to get all skins for this system (unfiltered)
                let allSystemSkins = try await skinManager.skins(for: system)
                DLOG("Total skins for \(system.systemName): \(allSystemSkins.count)")
                
                // Log details about the first few skins to help diagnose issues
                for (index, skin) in allSystemSkins.prefix(3).enumerated() {
                    DLOG("System skin \(index+1): \(skin.name), ID: \(skin.identifier)")
                    
                    // Check if this skin has representations for our device
                    if let jsonRep = skin.jsonRepresentation["representations"] as? [String: Any] {
                        let deviceKeys = jsonRep.keys.joined(separator: ", ")
                        DLOG("  Available devices: \(deviceKeys)")
                        
                        // Check for our device specifically
                        for (key, value) in jsonRep {
                            if key.lowercased() == currentDevice.rawValue.lowercased(), 
                               let deviceRep = value as? [String: Any] {
                                let displayTypes = deviceRep.keys.joined(separator: ", ")
                                DLOG("  ✅ Found \(currentDevice) support with display types: \(displayTypes)")
                                
                                // Check for standard display type
                                if let standardRep = deviceRep["standard"] as? [String: Any] {
                                    let orientations = standardRep.keys.joined(separator: ", ")
                                    DLOG("    Standard display orientations: \(orientations)")
                                }
                            }
                        }
                    }
                }
                
                // Load all skins for this system and device (without orientation filtering)
                // This gives us the full set of skins to filter by orientation later
                let skins = try await skinManager.skins(for: system, device: currentDevice)
                DLOG("Loaded \(skins.count) skins compatible with \(currentDevice) for \(system.systemName)")

                // Get currently selected skins for both orientations
                let portraitSelection = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: system, orientation: .portrait)
                let landscapeSelection = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: system, orientation: .landscape)
                DLOG("Selected skins - Portrait: \(portraitSelection ?? "none"), Landscape: \(landscapeSelection ?? "none")")

                // Update UI on main thread
                await MainActor.run {
                    self.availableSkins = skins
                    self.selectedPortraitSkinId = portraitSelection
                    self.selectedLandscapeSkinId = landscapeSelection
                    updateSelectedSkinId()
                    filterSkins()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    ELOG("Error loading skins: \(error)")
                }
            }
        }
    }
    
    /// Filter skins based on current device and orientation
    private func filterSkins() {
        DLOG("Filtering \(availableSkins.count) skins for \(currentDevice) in \(currentOrientation) mode")
        
        // Log details about the first few available skins
        for (index, skin) in availableSkins.prefix(3).enumerated() {
            DLOG("Available skin \(index+1): \(skin.name), ID: \(skin.identifier)")
        }
        
        // Filter the available skins to only show those that support the current orientation
        filteredSkins = availableSkins.filter { skin in
            DLOG("Checking if \(skin.name) supports \(currentDevice) in \(currentOrientation) orientation")
            
            // Use the protocol extension method that handles all the matching logic
            let supported = skin.supports(currentDevice)
            
            if supported {
                DLOG("✅ Skin \(skin.name) supports \(currentDevice) in \(currentOrientation) mode")
            } else {
                DLOG("❌ Skin \(skin.name) does not support \(currentDevice) in \(currentOrientation) mode")
            }
            
            return supported
        }
        
        DLOG("Filtered skins for \(currentDevice) in \(currentOrientation): \(filteredSkins.count) of \(availableSkins.count)")
        
        // Log the filtered skins
        for (index, skin) in filteredSkins.prefix(5).enumerated() {
            DLOG("Filtered skin \(index+1): \(skin.name)")
        }
        
        // If the currently selected skin isn't compatible with the current orientation,
        // we should clear the selection
        if let currentId = currentSelectedSkinId,
           !filteredSkins.contains(where: { $0.identifier == currentId }) {
            DLOG("Currently selected skin \(currentId) is not compatible with \(currentOrientation) orientation, clearing selection")
            selectSkin(nil)
        }
    }
    
    /// Update the currently selected skin ID based on orientation
    private func updateSelectedSkinId() {
        // This method is now a no-op since we're using a computed property
        // The currentSelectedSkinId getter will return the correct value based on orientation
    }
    
    /// Current selected skin ID based on orientation
    private var currentSelectedSkinId: String? {
        get {
            currentOrientation == .portrait ? selectedPortraitSkinId : selectedLandscapeSkinId
        }
        set {
            // Cannot directly assign to self in a computed property
            // We'll handle this in the updateSelectedSkinId method
        }
    }
    
    /// Update the selected skin ID for the current orientation
    private func updateCurrentSelectedSkinId(_ newValue: String?) {
        if currentOrientation == .portrait {
            selectedPortraitSkinId = newValue
        } else {
            selectedLandscapeSkinId = newValue
        }
    }

    private func selectSkin(_ identifier: String?) {
        Task {
            // Save selection for current orientation only
            await DeltaSkinPreferences.shared.setSelectedSkin(identifier, for: system, orientation: currentOrientation)
            
            await MainActor.run {
                // Update the appropriate orientation selection
                updateCurrentSelectedSkinId(identifier)
                // No need to call updateSelectedSkinId() since it's now a no-op
            }
        }
    }

    private func deleteSkin(_ skin: DeltaSkinProtocol) {
        Task {
            do {
                try await skinManager.deleteSkin(skin.identifier)

                // If we deleted the selected skin, reset selection for both orientations
                if selectedPortraitSkinId == skin.identifier {
                    await DeltaSkinPreferences.shared.setSelectedSkin(nil, for: system, orientation: .portrait)
                }
                
                if selectedLandscapeSkinId == skin.identifier {
                    await DeltaSkinPreferences.shared.setSelectedSkin(nil, for: system, orientation: .landscape)
                }

                // Reload skins
                loadSkins()
            } catch {
                print("Error deleting skin: \(error)")
            }
        }
    }
}

/// Enhanced skin preview that renders the actual skin with test pattern
struct EnhancedSkinPreview: View {
    let skin: DeltaSkinProtocol
    let orientation: DeltaSkinOrientation
    let device: DeltaSkinDevice
    
    @State private var previewImage: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    // Cache for preview images to avoid regenerating them
    private static var previewCache: [String: UIImage] = [:]
    
    private var cacheKey: String {
        "\(skin.identifier)_\(device.rawValue)_\(orientation.rawValue)"
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let image = previewImage {
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
            loadOrGeneratePreview()
        }
    }
    
    private func loadOrGeneratePreview() {
        // Check cache first
        if let cachedImage = Self.previewCache[cacheKey] {
            previewImage = cachedImage
            isLoading = false
            return
        }
        
        Task {
            do {
                // Create traits for the specific device and orientation
                let traits = DeltaSkinTraits(
                    device: device,
                    displayType: .standard,
                    orientation: orientation
                )
                
                // Check if skin supports these traits
                guard skin.supports(traits) else {
                    throw NSError(domain: "SkinPreview", code: 404, userInfo: [NSLocalizedDescriptionKey: "Skin doesn't support this configuration"])
                }
                
                // Try to generate a preview by rendering the skin with a test pattern
                let renderedImage = try await generateSkinPreview(for: traits)
                
                await MainActor.run {
                    self.previewImage = renderedImage
                    Self.previewCache[cacheKey] = renderedImage
                    self.isLoading = false
                }
            } catch {
                // Fall back to basic image loading if preview generation fails
                do {
                    let traits = DeltaSkinTraits(
                        device: device,
                        displayType: .standard,
                        orientation: orientation
                    )
                    
                    let skinImage = try await skin.image(for: traits)
                    
                    await MainActor.run {
                        self.previewImage = skinImage
                        Self.previewCache[cacheKey] = skinImage
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
    
    /// Generate a preview by rendering the skin with a test pattern
    private func generateSkinPreview(for traits: DeltaSkinTraits) async throws -> UIImage {
        // Create a renderer to capture the skin view
        let renderer = await MainActor.run { () -> UIGraphicsImageRenderer in
            // Determine size based on device and orientation
            let size: CGSize
            if device == .ipad {
                size = orientation == .portrait ? CGSize(width: 768, height: 1024) : CGSize(width: 1024, height: 768)
            } else {
                size = orientation == .portrait ? CGSize(width: 390, height: 844) : CGSize(width: 844, height: 390)
            }
            
            return UIGraphicsImageRenderer(size: size)
        }
        
        // Create a dummy input handler for the preview
        let inputHandler = DeltaSkinInputHandler()
        
        // Render the skin view to an image
        return await MainActor.run {
            renderer.image { context in
                // Create a view to render
                let skinView = DeltaSkinView(
                    skin: skin,
                    traits: traits,
                    filters: [.pixelated],  // Use pixelated effect for preview
                    showDebugOverlay: false,
                    showHitTestOverlay: false,
                    isInEmulator: false,
                    inputHandler: inputHandler
                )
                
                // Create a hosting controller to render the SwiftUI view
                let hostingController = UIHostingController(rootView: skinView)
                hostingController.view.frame = CGRect(origin: .zero, size: renderer.format.bounds.size)
                hostingController.view.backgroundColor = .clear
                
                // Render the view
                hostingController.view.drawHierarchy(in: renderer.format.bounds, afterScreenUpdates: true)
            }
        }
    }
}
