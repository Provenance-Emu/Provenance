import SwiftUI
import PVPrimitives
import PVLibrary

/// View for selecting a skin for a specific system with retrowave styling
public struct SystemSkinSelectionView: View {
    // MARK: - Properties

    let system: SystemIdentifier
    let game: PVGame?

    @StateObject private var skinManager = DeltaSkinManager.shared
    @StateObject private var preferences = DeltaSkinPreferences.shared

    // Skin data
    @State private var availableSkins: [DeltaSkinProtocol] = []
    @State private var portraitSkins: [DeltaSkinProtocol] = []
    @State private var landscapeSkins: [DeltaSkinProtocol] = []
    @State private var selectedSkinId: String?
    @State private var selectedPortraitSkinId: String?
    @State private var selectedLandscapeSkinId: String?
    @State private var selectedOrientation: SkinOrientation = .portrait

    // UI state
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadingProgress: Double = 0

    // Animation properties
    @State private var glowIntensity: CGFloat = 0.5
    @State private var selectedCellScale: CGFloat = 1.0
    @State private var hoveredSkinId: String? = nil

    @Environment(\.dismiss) private var dismiss

    public init(system: SystemIdentifier, game: PVGame? = nil) {
        self.system = system
        self.game = game
    }

    /// Whether this is a per-game skin selection
    private var isPerGameSelection: Bool {
        game != nil
    }

    /// The game ID for per-game preferences
    private var gameId: String? {
        game?.id
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
                .ignoresSafeArea()

            // Main content
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
                            // Header with system name
                            headerView

                            // Orientation picker
                            orientationPickerView

                            // Skin grid for selected orientation
                            skinGridView
                        }
                    }
                }
                .navigationTitle(isPerGameSelection ? "\(game?.title ?? "Game") Skin" : "\(system.fullName) Skins")
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                loadSkins()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Start glow animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }

            // Only load if skins aren't already cached, otherwise use cached data
            if skinManager.loadedSkins.isEmpty {
                // Load skins with a slight delay for animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    loadSkins()
                }
            } else {
                // Use cached skins immediately
                Task {
                    await loadSkinsFromCache()
                }
            }
        }
        .onChange(of: skinManager.loadedSkins.count) { _ in
            // Reload when manager's skins change (e.g., after import)
            Task {
                await loadSkinsFromCache()
            }
        }
    }

    // MARK: - UI Components

    private var headerView: some View {
        VStack(spacing: 6) {
            Text(system.fullName.uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .padding(.top, 16)
                .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.5), radius: 2)

            Text("Select a controller skin")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, RetroTheme.retroPink.opacity(0.3), .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blendMode(.overlay)
                )
        )
    }

    // Helper view for orientation tab button to simplify the complex ForEach
    private func orientationTabButton(for orientation: SkinOrientation) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedOrientation = orientation
            }
        } label: {
            HStack {
                Image(systemName: orientation.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(orientation.displayName.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(selectedOrientation == orientation ?
                        Color.black.opacity(0.6) :
                        Color.black.opacity(0.3))
            .foregroundColor(selectedOrientation == orientation ?
                             .white :
                             .white.opacity(0.6))
            .overlay(selectedOrientation == orientation ? tabButtonBorder : nil)
        }
    }

    // Extract the border as a separate property to reduce nesting
    private var tabButtonBorder: some View {
        RoundedRectangle(cornerRadius: 0)
            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
            .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 3)
    }

    private var orientationPickerView: some View {
        VStack(spacing: 8) {
            // Custom segmented control with retrowave styling
            HStack(spacing: 0) {
                ForEach(SkinOrientation.allCases, id: \.self) { orientation in
                    orientationTabButton(for: orientation)
                }
            }
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 30) {
            Spacer()

            // Retrowave styled loading indicator
            ZStack {
                Circle()
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        lineWidth: 4
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 2 * glowIntensity)

                Circle()
                    .trim(from: 0, to: loadingProgress)
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)

                Text("\(Int(loadingProgress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    loadingProgress = 1.0
                }
            }

            Text("LOADING SKINS")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                .padding(.bottom, 10)

            Text("ERROR LOADING SKINS")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                withAnimation {
                    loadSkins()
                }
            } label: {
                Text("TRY AGAIN")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                            )
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
                .padding(.horizontal)
        )
    }

    private var noSkinsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                .padding(.bottom, 10)

            Text("NO SKINS AVAILABLE")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text("There are no controller skins available for \(system.fullName)")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                // Show skin import UI - would be implemented in future
                // For now, just reload to check again
                withAnimation {
                    loadSkins()
                }
            } label: {
                Text("IMPORT SKIN")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                            )
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
                .padding(.horizontal)
        )
    }

    private var skinGridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Show current selection status with retrowave styling
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .font(.system(size: 14))

                    Text(selectedOrientation == .portrait ?
                         "Selected skin will be used in portrait mode" :
                         "Selected skin will be used in landscape mode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Skin grid with retrowave styling
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)], spacing: 24) {
                    // Default option (system default)
                    defaultSkinCell

                    // Available skins for the selected orientation
                    let filteredSkins = selectedOrientation == .portrait ? portraitSkins : landscapeSkins
                    ForEach(filteredSkins, id: \.identifier) { skin in
                        skinCell(for: skin)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var defaultSkinCell: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background with retrowave styling
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .aspectRatio(1.5, contentMode: .fit)

                // Controller icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.7), radius: 3)
            }
            .overlay(
                // Selection indicator
                Group {
                    if currentSelectedSkinId == nil {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 2.5)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.clear, lineWidth: 2.5)
                    }
                }
                    .shadow(color: currentSelectedSkinId == nil ? RetroTheme.retroPink.opacity(0.7) : .clear, radius: 3)
            )
            .scaleEffect(currentSelectedSkinId == nil ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSelectedSkinId)

            // Label
            Text("SYSTEM DEFAULT")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(currentSelectedSkinId == nil ? .white : .white.opacity(0.7))
                .lineLimit(1)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectSkin(nil)
            }
        }
        .padding(.bottom, 8)
    }

    // Helper property to get the current selected skin ID based on orientation
    private var currentSelectedSkinId: String? {
        selectedOrientation == .portrait ? selectedPortraitSkinId : selectedLandscapeSkinId
    }

    private func skinCell(for skin: DeltaSkinProtocol) -> some View {
        let isSelected = currentSelectedSkinId == skin.identifier
        let isHovered = hoveredSkinId == skin.identifier

        return VStack(spacing: 8) {
            ZStack {
                // Skin preview with correct orientation and retrowave styling
                SkinSelectionPreviewCell(skin: skin, manager: skinManager, orientation: selectedOrientation.deltaSkinOrientation)
                    .cornerRadius(12)
            }
            .overlay(
                // Selection indicator with retrowave styling
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 2.5)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.clear, lineWidth: 2.5)
                    }
                }
                    .shadow(color: isSelected ? RetroTheme.retroPink.opacity(0.7) : .clear, radius: 3)
            )
            .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)

            // Skin name with retrowave styling
            Text(skin.name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .lineLimit(1)
        }
#if !os(tvOS)
        .onHover { hovering in
            hoveredSkinId = hovering ? skin.identifier : nil
        }
        #endif
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectSkin(skin.identifier)
            }
        }
        .padding(.bottom, 8)
        .contextMenu {
            Button {
                selectSkin(skin.identifier)
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }

            Button {
                // Select for both orientations
                Task {
                    if isPerGameSelection, let gameId = gameId {
                        await preferences.setSelectedSkin(skin.identifier, for: gameId, orientation: .portrait)
                        await preferences.setSelectedSkin(skin.identifier, for: gameId, orientation: .landscape)
                        skinManager.setSessionSkin(skin.identifier, for: system, gameId: gameId, orientation: .portrait)
                        skinManager.setSessionSkin(skin.identifier, for: system, gameId: gameId, orientation: .landscape)
                    } else {
                        await preferences.setSelectedSkin(skin.identifier, for: system, orientation: .portrait)
                        await preferences.setSelectedSkin(skin.identifier, for: system, orientation: .landscape)
                        skinManager.setSessionSkin(skin.identifier, for: system, orientation: .portrait)
                        skinManager.setSessionSkin(skin.identifier, for: system, orientation: .landscape)
                    }
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

    // MARK: - Data Handling

    /// Load skins from cache (fast path when skins are already loaded)
    private func loadSkinsFromCache() async {
        await MainActor.run {
            isLoading = false
            errorMessage = nil
            loadingProgress = 1.0
        }

        do {
            // Use cached skins - this will filter from already-loaded skins without rescanning
            let skins = try await skinManager.skins(for: system)
            await processSkins(skins)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Process skins and update UI state
    private func processSkins(_ skins: [DeltaSkinProtocol]) async {
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
        let portraitSelection: String?
        let landscapeSelection: String?

        if isPerGameSelection, let gameId = gameId {
            // Load per-game preferences
            portraitSelection = preferences.selectedSkinIdentifier(for: gameId, orientation: .portrait)
            landscapeSelection = preferences.selectedSkinIdentifier(for: gameId, orientation: .landscape)
        } else {
            // Load system preferences
            portraitSelection = preferences.selectedSkinIdentifier(for: system, orientation: .portrait)
            landscapeSelection = preferences.selectedSkinIdentifier(for: system, orientation: .landscape)
        }

        // Update UI on main thread
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                self.availableSkins = skins
                self.portraitSkins = portraitCompatible
                self.landscapeSkins = landscapeCompatible
                self.selectedPortraitSkinId = portraitSelection
                self.selectedLandscapeSkinId = landscapeSelection
                self.isLoading = false
                self.loadingProgress = 1.0
            }
        }
    }

    private func loadSkins() {
        isLoading = true
        errorMessage = nil
        loadingProgress = 0.1

        Task {
            // Only show progress animation if skins aren't cached
            if skinManager.loadedSkins.isEmpty {
                // Simulate progress for better UX
                Task {
                    for progress in stride(from: 0.1, to: 0.9, by: 0.1) {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        await MainActor.run {
                            loadingProgress = progress
                        }
                    }
                }
            } else {
                // Skip progress animation if using cache
                await MainActor.run {
                    loadingProgress = 0.9
                }
            }

            do {
                // Load all skins for this system (will use cache if available)
                let skins = try await skinManager.skins(for: system)
                await processSkins(skins)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    loadingProgress = 1.0

                    // Slight delay for animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }

    private func selectSkin(_ identifier: String?) {
        Task {
            if isPerGameSelection, let gameId = gameId {
                // Set per-game preference
                await preferences.setSelectedSkin(identifier, for: gameId, orientation: selectedOrientation)

                // Also update session skin for immediate effect
                if let identifier = identifier {
                    skinManager.setSessionSkin(identifier, for: system, gameId: gameId, orientation: selectedOrientation)
                } else {
                    skinManager.setSessionSkin(nil, for: system, gameId: gameId, orientation: selectedOrientation)
                }
            } else {
                // Set system preference
                await preferences.setSelectedSkin(identifier, for: system, orientation: selectedOrientation)

                // Also update session skin for immediate effect
                if let identifier = identifier {
                    skinManager.setSessionSkin(identifier, for: system, orientation: selectedOrientation)
                } else {
                    skinManager.setSessionSkin(nil, for: system, orientation: selectedOrientation)
                }
            }

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
                    if isPerGameSelection, let gameId = gameId {
                        await preferences.setSelectedSkin(nil, for: gameId, orientation: .portrait)
                        skinManager.setSessionSkin(nil, for: system, gameId: gameId, orientation: .portrait)
                    } else {
                        await preferences.setSelectedSkin(nil, for: system, orientation: .portrait)
                        skinManager.setSessionSkin(nil, for: system, orientation: .portrait)
                    }
                }

                if selectedLandscapeSkinId == skin.identifier {
                    if isPerGameSelection, let gameId = gameId {
                        await preferences.setSelectedSkin(nil, for: gameId, orientation: .landscape)
                        skinManager.setSessionSkin(nil, for: system, gameId: gameId, orientation: .landscape)
                    } else {
                        await preferences.setSelectedSkin(nil, for: system, orientation: .landscape)
                        skinManager.setSessionSkin(nil, for: system, orientation: .landscape)
                    }
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
struct SkinSelectionPreviewCell: View {
    let skin: DeltaSkinProtocol
    let manager: DeltaSkinManager
    var orientation: DeltaSkinOrientation = .portrait

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var previewTraits: DeltaSkinTraits {
        // Try current device first with specified orientation
        let device: DeltaSkinDevice = horizontalSizeClass == .regular ? .ipad : .iphone
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)

        // Return first supported configuration
        if skin.supports(traits) {
            return traits
        }

        // Try with edge to edge display type
        let edgeToEdgeTraits = DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: orientation)
        if skin.supports(edgeToEdgeTraits) {
            return edgeToEdgeTraits
        }

        // Try alternate device
        let altDevice: DeltaSkinDevice = device == .ipad ? .iphone : .ipad
        let altTraits = DeltaSkinTraits(device: altDevice, displayType: .standard, orientation: orientation)

        if skin.supports(altTraits) {
            return altTraits
        }

        // Try alternate device with edge to edge
        let altEdgeToEdgeTraits = DeltaSkinTraits(device: altDevice, displayType: .edgeToEdge, orientation: orientation)
        if skin.supports(altEdgeToEdgeTraits) {
            return altEdgeToEdgeTraits
        }

        // If the requested orientation isn't supported, try the opposite orientation
        let oppositeOrientation: DeltaSkinOrientation = orientation == .portrait ? .landscape : .portrait
        let oppositeTraits = DeltaSkinTraits(device: device, displayType: .standard, orientation: oppositeOrientation)

        if skin.supports(oppositeTraits) {
            return oppositeTraits
        }

        // Fallback to edge to edge with default orientation
        return DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .portrait)
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else {
                DeltaSkinView(skin: skin, traits: previewTraits, inputHandler: .init(emulatorCore: nil))
                    .allowsHitTesting(false)
                    .aspectRatio(orientation == .portrait ? 0.5 : 2.0, contentMode: .fit)
            }
        }
        .onAppear {
            loadSkinImage()
        }
    }

    private func loadSkinImage() {
        Task {
            do {
                // Wait a brief moment to allow for animation
                try? await Task.sleep(nanoseconds: 100_000_000)

                // Simulate loading the skin image
                try? await Task.sleep(nanoseconds: 200_000_000)

                await MainActor.run {
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
