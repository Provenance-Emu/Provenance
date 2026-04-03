import SwiftUI
import PVPrimitives
import PVLibrary
import PVLogging
import PVFeatureFlags
import UniformTypeIdentifiers
#if canImport(SafariServices)
import SafariServices
#endif

/// View for selecting a skin for a specific system with retrowave styling
// swiftlint:disable type_body_length
public struct SystemSkinSelectionView: View {
    // MARK: - Properties

    let system: SystemIdentifier
    let game: PVGame?

    @ObservedObject private var skinManager = DeltaSkinManager.shared
    @ObservedObject private var selectionManager = DeltaSkinSelectionManager.shared

    // Skin data
    @State private var availableSkins: [DeltaSkinProtocol] = []
    @State private var portraitSkins: [DeltaSkinProtocol] = []
    @State private var landscapeSkins: [DeltaSkinProtocol] = []
    @State private var selectedSkinId: String?
    @State private var selectedPortraitSkinId: String?
    @State private var selectedLandscapeSkinId: String?
    @State private var selectedOrientation: SkinOrientation
    @State private var selectedScope: SkinScope

    // UI state
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadingProgress: Double = 0
    @State private var showingDocumentPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?

    // Animation properties
    @State private var glowIntensity: CGFloat = 0.5
    @State private var selectedCellScale: CGFloat = 1.0
    @State private var hoveredSkinId: String? = nil
#if !os(tvOS)
    /// Collapsed by default so GameSir / Buppin / Soolra companion skins do not clutter the main grid.
    @State private var caseSkinsSectionExpanded = false
#endif

    @Environment(\.dismiss) private var dismiss

    public init(
        system: SystemIdentifier,
        game: PVGame? = nil,
        preferredScope: SkinScope? = nil,
        preferredOrientation: SkinOrientation = .portrait
    ) {
        self.system = system
        self.game = game
        _selectedOrientation = State(initialValue: preferredOrientation)
        _selectedScope = State(initialValue: preferredScope ?? (game != nil ? .game : .system))
    }

    /// Whether this is a per-game skin selection
    private var isPerGameSelection: Bool {
        game != nil
    }

    /// The game ID for per-game/session preferences
    private var gameId: String? {
        game?.id
    }

    /// Current scope with safety fallback when game scope is unavailable.
    private var effectiveScope: SkinScope {
        if selectedScope == .game, gameId == nil {
            return .system
        }
        return selectedScope
    }

    /// Game ID used for writes/reads at the current scope.
    private var scopedGameId: String? {
        switch effectiveScope {
        case .system:
            return nil
        case .session, .game:
            return gameId
        }
    }

    /// System short code for skin catalog filter (e.g. "nes", "snes")
    private var catalogSystemFilter: String? {
        system.skinCatalogSystemCode
    }

    /// Get the current device type
    private var currentDevice: DeltaSkinDevice {
        #if os(tvOS)
        // No real .deltaskin files use "tv" — iPad landscape skins work best at TV scale
        return .ipad
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }

    /// Filter skins to only show those that support the selected orientation for the current device
    private var filteredSkinsForCurrentOrientation: [DeltaSkinProtocol] {
        availableSkins.filter { skin in
            skinSupportsOrientation(skin, orientation: selectedOrientation)
        }
    }

    /// Skins for the main grid — always excludes case-controller skins (they appear in their own section when the flag is on).
    private var regularSkinsForCurrentOrientation: [DeltaSkinProtocol] {
        filteredSkinsForCurrentOrientation.filter { !$0.isCaseControllerSkin }
    }

    /// Companion skins (phone-case controllers) — gated behind the `caseCompanionSkins` feature flag.
    private var caseCompanionSkinsForCurrentOrientation: [DeltaSkinProtocol] {
#if os(tvOS)
        []
#else
        guard PVFeatureFlagsManager.shared.caseCompanionSkins else { return [] }
        return filteredSkinsForCurrentOrientation.filter { $0.isCaseControllerSkin }
#endif
    }

    private var skinSelectionGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]
    }

#if !os(tvOS)
    /// Label row for the case companion skins `DisclosureGroup`.
    private var caseCompanionSkinsSectionLabel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text("Case controller skins")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("GameSir, Buppin, Soolra, and similar — expand if you use one of these accessories.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    /// Grid of case companion skins inside the disclosure section.
    private var caseCompanionSkinsGrid: some View {
        LazyVGrid(columns: skinSelectionGridColumns, spacing: 24) {
            ForEach(caseCompanionSkinsForCurrentOrientation, id: \.identifier) { skin in
                skinCell(for: skin)
            }
        }
    }
#endif

    /// Check if a skin supports a given orientation for the current device
    private func skinSupportsOrientation(_ skin: DeltaSkinProtocol, orientation: SkinOrientation) -> Bool {
        let device = currentDevice
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        for display in displayTypes {
            let traits = DeltaSkinTraits(
                device: device,
                displayType: display,
                orientation: orientation.deltaSkinOrientation
            )
            if skin.supports(traits) { return true }
        }
        return false
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
                .ignoresSafeArea()

            // Main content
            NavigationStack {
                Group {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(message: error)
                    } else {
                        VStack(spacing: 0) {
                            // Header with system name
                            headerView

                            // Orientation picker
                            orientationPickerView

                            // Skin grid for selected orientation (always shown so Default is accessible)
                            skinGridView
                        }
                    }
                }
                .navigationTitle(isPerGameSelection ? "\(game?.title ?? "Game") Skin" : "\(system.fullName) Skins")
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: SkinCatalogBrowserView(preselectedSystem: catalogSystemFilter)) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                Text("Get More")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        }
                    }

                    #if !os(tvOS)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        }
                    }
                    #endif

                    ToolbarItem(placement: .topBarTrailing) {
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
        .onChange(of: selectedOrientation) { newOrientation in
            // Validate current selection when orientation changes
            Task {
                await validateSelectionForOrientation(newOrientation)
            }
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: supportedSkinTypes,
            allowsMultipleSelection: true
        ) { result in
            Task {
                do {
                    let urls = try result.get()
                    try await importSkins(from: urls)
                } catch {
                    importError = error
                    showingImportError = true
                }
            }
        }
        .retroAlert("Import Error",
                    message: importError?.localizedDescription ?? "Failed to import skin",
                    isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        }
        #endif
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
            HStack(spacing: 0) {
                ForEach(SkinScope.allCases) { scope in
                    let enabled = scope != .game || gameId != nil
                    Button {
                        guard enabled else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedScope = scope
                        }
                    } label: {
                        Text(scope.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(effectiveScope == scope ? Color.black.opacity(0.6) : Color.black.opacity(0.3))
                            .foregroundColor(enabled ? (effectiveScope == scope ? .white : .white.opacity(0.7)) : .white.opacity(0.35))
                    }
                    .disabled(!enabled)
                }
            }
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal)
            .padding(.top, 12)

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

            #if os(tvOS)
            NavigationLink(destination: SkinCatalogBrowserView(preselectedSystem: catalogSystemFilter)) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("BROWSE SKIN CATALOG")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
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
            .retroFocusButtonStyle()
            #else
            HStack(spacing: 12) {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Text("IMPORT SKIN")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
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

                NavigationLink(destination: SkinCatalogBrowserView(preselectedSystem: catalogSystemFilter)) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("BROWSE CATALOG")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
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
            }
            #endif

            // DeltaStyles link component
            DeltaStylesLinkView()
                .padding(.horizontal)
                .padding(.top, 8)

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
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: supportedSkinTypes,
            allowsMultipleSelection: true
        ) { result in
            Task {
                do {
                    let urls = try result.get()
                    try await importSkins(from: urls)
                } catch {
                    importError = error
                    showingImportError = true
                }
            }
        }
        .retroAlert("Import Error",
                    message: importError?.localizedDescription ?? "Failed to import skin",
                    isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        }
        #endif
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

                // Skin grid with retrowave styling (iOS: case companion skins may appear in a disclosure section below)
                LazyVGrid(columns: skinSelectionGridColumns, spacing: 24) {
                    defaultSkinCell

                    ForEach(regularSkinsForCurrentOrientation, id: \.identifier) { skin in
                        skinCell(for: skin)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

#if !os(tvOS)
                if !caseCompanionSkinsForCurrentOrientation.isEmpty {
                    DisclosureGroup(isExpanded: $caseSkinsSectionExpanded) {
                        caseCompanionSkinsGrid
                            .padding(.top, 8)
                    } label: {
                        caseCompanionSkinsSectionLabel
                    }
                    .tint(RetroTheme.retroPink)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
#endif

                Spacer(minLength: 0)
                    .frame(height: 20)

                // No third-party skins message (shown inline so Default is still accessible)
                if regularSkinsForCurrentOrientation.isEmpty && caseCompanionSkinsForCurrentOrientation.isEmpty {
                    VStack(spacing: 8) {
                        Text("No custom skins available for \(system.fullName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
#if os(tvOS)
                        Text("Download skins below.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
#else
                        Text("Download skins below or import a .deltaskin file.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
#endif
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                // DeltaStyles link component
                DeltaStylesLinkView()
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
        let isLandscape = selectedOrientation == .landscape

        return VStack(spacing: 8) {
            ZStack {
                // Background for proper clipping
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))

                // Skin preview with correct orientation and retrowave styling
                SkinSelectionPreviewCell(skin: skin, manager: skinManager, orientation: selectedOrientation.deltaSkinOrientation)
                    .id("\(skin.identifier)-\(selectedOrientation)")
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .aspectRatio(isLandscape ? 2.0 : 0.5, contentMode: .fit)
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
                    await selectionManager.setSkin(skin.identifier, for: system, gameId: scopedGameId, orientation: .portrait, scope: effectiveScope)
                    await selectionManager.setSkin(skin.identifier, for: system, gameId: scopedGameId, orientation: .landscape, scope: effectiveScope)
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

    /// Comprehensive list of UTTypes for skin file imports
    /// Supports both .deltaskin and .manicskin in file, package, and archive forms
    private var supportedSkinTypes: [UTType] {
        var skinTypes: [UTType] = []

        // Prefer explicit identifiers if the system recognizes them
        skinTypes.append(UTType.deltaSkin)
        skinTypes.append(UTType.deltaAppSkin)
        skinTypes.append(UTType.manicSkin)

        // Accept files with these extensions (generic data)
        if let deltaskinData = UTType(filenameExtension: "deltaskin", conformingTo: .data) {
            skinTypes.append(deltaskinData)
        }
        if let manicData = UTType(filenameExtension: "manicskin", conformingTo: .data) {
            skinTypes.append(manicData)
        }

        // Accept package (directory bundle) variants (some providers surface bundles)
        if let deltaskinPackage = UTType(filenameExtension: "deltaskin", conformingTo: .package) {
            skinTypes.append(deltaskinPackage)
        }
        if let manicPackage = UTType(filenameExtension: "manicskin", conformingTo: .package) {
            skinTypes.append(manicPackage)
        }

        // Accept archive-conforming variants (these are actually ZIPs with custom extensions)
        if let deltaskinArchive = UTType(filenameExtension: "deltaskin", conformingTo: .archive) {
            skinTypes.append(deltaskinArchive)
        }
        if let manicArchive = UTType(filenameExtension: "manicskin", conformingTo: .archive) {
            skinTypes.append(manicArchive)
        }

        // Also allow generic archives (some skins are zipped variants)
        skinTypes.append(.archive)

        return skinTypes
    }

    /// Import skins from URLs
    private func importSkins(from urls: [URL]) async throws {
        for url in urls {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw DeltaSkinError.accessDenied
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Import the skin
            try await skinManager.importSkin(from: url)
        }

        // Reload skins after import
        await skinManager.reloadSkins()

        // Reload the view's skins
        await loadSkinsFromCache()
    }

    /// Load skins from cache (fast path when skins are already loaded)
    private func loadSkinsFromCache() async {
        await MainActor.run {
            isLoading = false
            errorMessage = nil
            loadingProgress = 1.0
        }

        // Use the same method as RetroMenuView to ensure consistent filtering
        do {
            let allSkins = try await skinManager.availableSkins()
            ILOG("skins: [SelectionView] Total loaded skins: \(allSkins.count), filtering for system: \(system.rawValue)")
            let filteredSkins = try await skinManager.skins(for: system)
            ILOG("skins: [SelectionView] After system filter: \(filteredSkins.count) skins for \(system.rawValue)")
            if filteredSkins.isEmpty && !allSkins.isEmpty {
                // Log game types of all loaded skins for debugging
                let gameTypes = Set(allSkins.map { "\($0.gameType)" })
                WLOG("skins: [SelectionView] No skins matched system \(system.rawValue). Available game types: \(gameTypes.sorted().joined(separator: ", "))")
            }
            await processSkins(filteredSkins)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Process skins and update UI state
    private func processSkins(_ skins: [DeltaSkinProtocol]) async {
        // Filter skins to only include those that support the current device type
        // This ensures we don't show iPhone-only skins on iPad or vice versa
        let device = currentDevice
        ILOG("skins: [SelectionView] processSkins: \(skins.count) skins, device=\(device.rawValue)")
        let deviceFilteredSkins = skins.filter { skin in
            let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
            let orientations: [SkinOrientation] = [.portrait, .landscape]

            // Check if skin supports at least one orientation for the current device
            for orientation in orientations {
                for display in displayTypes {
                    let traits = DeltaSkinTraits(
                        device: device,
                        displayType: display,
                        orientation: orientation.deltaSkinOrientation
                    )
                    if skin.supports(traits) { return true }
                }
            }
            WLOG("skins: [SelectionView] Skin '\(skin.name)' (\(skin.identifier)) rejected — no representations for device \(device.rawValue)")
            return false
        }
        ILOG("skins: [SelectionView] After device filter: \(deviceFilteredSkins.count) skins (rejected \(skins.count - deviceFilteredSkins.count))")

        // Get currently selected skins for both orientations using centralized manager
        let portraitSelection: String?
        let landscapeSelection: String?

        portraitSelection = selectionManager.effectiveSkinIdentifier(for: system, gameId: scopedGameId, orientation: .portrait)
        landscapeSelection = selectionManager.effectiveSkinIdentifier(for: system, gameId: scopedGameId, orientation: .landscape)

        // Update UI on main thread
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                // Store device-filtered skins - will be further filtered by orientation in filteredSkinsForCurrentOrientation
                self.availableSkins = deviceFilteredSkins
                self.portraitSkins = deviceFilteredSkins
                self.landscapeSkins = deviceFilteredSkins
                self.selectedPortraitSkinId = portraitSelection
                self.selectedLandscapeSkinId = landscapeSelection
                self.isLoading = false
                self.loadingProgress = 1.0
            }

#if !os(tvOS)
            /// Open the case skins section when it is the only option for this orientation, or when the active pick is a case skin.
            let filteredForUI = deviceFilteredSkins.filter { self.skinSupportsOrientation($0, orientation: self.selectedOrientation) }
            let regularCount = filteredForUI.filter { !$0.isCaseControllerSkin }.count
            let caseCount = filteredForUI.filter { $0.isCaseControllerSkin }.count
            let onlyCaseSkinsShown = regularCount == 0 && caseCount > 0
            let activeId = self.selectedOrientation == .portrait ? portraitSelection : landscapeSelection
            let selectionIsCaseSkin = activeId.map { id in filteredForUI.first(where: { $0.identifier == id })?.isCaseControllerSkin ?? false } ?? false
            if onlyCaseSkinsShown || selectionIsCaseSkin {
                self.caseSkinsSectionExpanded = true
            }
#endif
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
                // Use the same method as RetroMenuView to ensure consistent filtering
                let filteredSkins = try await skinManager.skins(for: system)
                await processSkins(filteredSkins)
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
            if identifier == nil {
                // Reverting to default: for session/game persist the built-in token (so we do not inherit a system `.deltaskin`); for system scope clear prefs only.
                for orientation in SkinOrientation.allCases {
                    let stored: String? = {
                        switch effectiveScope {
                        case .system:
                            return nil
                        case .session, .game:
                            return DeltaSkinSelectionManager.builtInSkinPreferenceToken
                        }
                    }()
                    await selectionManager.setSkin(stored, for: system, gameId: scopedGameId, orientation: orientation, scope: effectiveScope)
                }
                await MainActor.run {
                    self.selectedPortraitSkinId = nil
                    self.selectedLandscapeSkinId = nil
                }
            } else {
                await selectionManager.setSkin(
                    identifier,
                    for: system,
                    gameId: scopedGameId,
                    orientation: selectedOrientation,
                    scope: effectiveScope
                )

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
    }

    /// Validate that the current selection supports the given orientation, clear if not
    private func validateSelectionForOrientation(_ orientation: SkinOrientation) async {
        let currentSelectionId = orientation == .portrait ? selectedPortraitSkinId : selectedLandscapeSkinId

        guard let selectionId = currentSelectionId,
              let selectedSkin = availableSkins.first(where: { $0.identifier == selectionId }) else {
            // No selection or skin not found, nothing to validate
            return
        }

        // Check if the selected skin supports this orientation for the current device
        if !skinSupportsOrientation(selectedSkin, orientation: orientation) {
            // Selection doesn't support this orientation, clear it
            await selectionManager.setSkin(
                nil,
                for: system,
                gameId: scopedGameId,
                orientation: orientation,
                scope: effectiveScope
            )

            // Update UI state
            await MainActor.run {
                if orientation == .portrait {
                    self.selectedPortraitSkinId = nil
                } else {
                    self.selectedLandscapeSkinId = nil
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
                    await selectionManager.setSkin(nil, for: system, gameId: scopedGameId, orientation: .portrait, scope: effectiveScope)
                }

                if selectedLandscapeSkinId == skin.identifier {
                    await selectionManager.setSkin(nil, for: system, gameId: scopedGameId, orientation: .landscape, scope: effectiveScope)
                }

                // Reload skins
                loadSkins()
            } catch {
                print("Error deleting skin: \(error)")
            }
        }
    }
}
// swiftlint:enable type_body_length

/// View component for linking to DeltaStyles website
private struct DeltaStylesLinkView: View {
    @State private var showSafariView = false

    private let deltaStylesURL = URL(string: "https://deltastyles.com")!

    var body: some View {
        VStack(spacing: 12) {
            // Info label
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)

                Text("Download more skins from DeltaStyles")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 4)

            // Button to open DeltaStyles
            #if !os(tvOS)
            Button {
                showSafariView = true
            } label: {
                HStack {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)

                    Text("Visit DeltaStyles.com")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
            }
            .sheet(isPresented: $showSafariView) {
                SafariWebView(url: deltaStylesURL, entersReaderIfAvailable: false)
            }
            #else
            Link(destination: deltaStylesURL) {
                HStack {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)

                    Text("Visit DeltaStyles.com")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
            }
            #endif
        }
        .padding(.vertical, 8)
    }
}

/// Helper view to display a skin preview image.
///
/// Loads the skin image on a background task and displays it as a static
/// thumbnail, avoiding the heavyweight ``DeltaSkinView`` in list contexts.
/// Uses an in-memory cache keyed by skin identifier + traits so scrolling
/// through many skins stays smooth.
struct SkinSelectionPreviewCell: View {
    let skin: DeltaSkinProtocol
    let manager: DeltaSkinManager
    var orientation: DeltaSkinOrientation = .portrait

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    /// Get the current device type (matches SystemSkinSelectionView logic)
    private var currentDevice: DeltaSkinDevice {
        #if os(tvOS)
        return .ipad
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }

    /// Resolve the best supported traits for preview, trying progressively
    /// wider fallbacks: current device -> alternate device, requested
    /// orientation -> opposite orientation, standard -> edgeToEdge.
    private var previewTraits: DeltaSkinTraits {
        let device = currentDevice
        let altDevice: DeltaSkinDevice = device == .ipad ? .iphone : .ipad
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        let oppositeOrientation: DeltaSkinOrientation = orientation == .portrait ? .landscape : .portrait

        // 1. Current device, requested orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: device, displayType: displayType, orientation: orientation)
            if skin.supports(traits) { return traits }
        }

        // 2. Current device, opposite orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: device, displayType: displayType, orientation: oppositeOrientation)
            if skin.supports(traits) { return traits }
        }

        // 3. Alternate device, requested orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: altDevice, displayType: displayType, orientation: orientation)
            if skin.supports(traits) { return traits }
        }

        // 4. Alternate device, opposite orientation
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: altDevice, displayType: displayType, orientation: oppositeOrientation)
            if skin.supports(traits) { return traits }
        }

        // Final fallback (should rarely be reached)
        return DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if loadFailed {
                // Lightweight fallback instead of "No Image"
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text(skin.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.15))
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: orientation) { _ in
            isLoading = true
            loadFailed = false
            thumbnailImage = nil
            loadThumbnail()
        }
    }

    // MARK: - Loading

    private func loadThumbnail() {
        let traits = previewTraits
        let cacheKey = "\(skin.identifier)-\(traits.device.rawValue)-\(traits.displayType.rawValue)-\(traits.orientation.rawValue)"

        // Fast path: use shared cache
        if let cached = SkinPreviewThumbnailCache.shared.thumbnail(forKey: cacheKey) {
            thumbnailImage = cached
            isLoading = false
            return
        }

        Task.detached(priority: .utility) {
            do {
                let image = try await skin.image(for: traits)
                SkinPreviewThumbnailCache.shared.store(image, forKey: cacheKey)
                await MainActor.run {
                    self.thumbnailImage = image
                    self.isLoading = false
                }
            } catch {
                ELOG("skins: SkinSelectionPreviewCell failed to load thumbnail for '\(skin.name)' traits=\(traits.description): \(error)")
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}
