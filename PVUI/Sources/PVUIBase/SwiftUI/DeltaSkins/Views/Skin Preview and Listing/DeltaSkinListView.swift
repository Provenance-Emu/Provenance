import SwiftUI
import PVLogging
import UniformTypeIdentifiers

/// View for listing available skins
private struct IdentifiableSkin: Identifiable, Hashable {
    let skin: DeltaSkinProtocol
    var id: String { skin.identifier }

    // Add Hashable conformance
    static func == (lhs: IdentifiableSkin, rhs: IdentifiableSkin) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Grid view for browsing and selecting skins
public struct DeltaSkinListView: View {
    @ObservedObject var manager: DeltaSkinManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingFullscreenPreview = false
    @State private var traits: DeltaSkinTraits?
    @State private var screenAspectRatio: CGFloat?
    @State private var availableSkins: [DeltaSkinProtocol] = []
    @State private var showingDocumentPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?

    // Dynamic grid sizing based on size class
    private var columns: [GridItem] {
        let minWidth: CGFloat = horizontalSizeClass == .regular ? 200 : 160
        return [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
    }

    public init(manager: DeltaSkinManager = .shared) {
        self.manager = manager
    }

    public var body: some View {
        SkinGridView(manager: manager, columns: columns)
            .navigationTitle("Skins")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingFullscreenPreview) {
                if !availableSkins.isEmpty {
                    DeltaSkinFullscreenPagerView(
                        skins: availableSkins,
                        traits: traits ?? DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait),
                        screenAspectRatio: screenAspectRatio
                    )
                }
            }
            .task {
                do {
                    availableSkins = try await manager.availableSkins()
                } catch {
                    ELOG("Failed to load skins: \(error)")
                }
            }
        #if !os(tvOS)
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [UTType.deltaSkin],
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
        #endif
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError?.localizedDescription ?? "Failed to import skin")
            }
    }

    private func importSkins(from urls: [URL]) async throws {
        for url in urls {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                ELOG("Failed to start accessing security-scoped resource")
                throw DeltaSkinError.accessDenied
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Import the skin
            try await manager.importSkin(from: url)
        }

        // Reload after all imports
        await manager.reloadSkins()
    }
}

/// Grid view with loading and error states
private struct SkinGridView: View {
    @ObservedObject var manager: DeltaSkinManager
    let columns: [GridItem]

    @State private var isLoading = true
    @State private var error: Error?

    /// Stores the expanded state of each console section as a comma-separated list of expanded section names
    @AppStorage("deltaSkinSectionStates") private var expandedSectionsString: String = ""

    /// Set of expanded section names for faster lookup
    @State private var expandedSections: Set<String> = []

    // Use manager's loadedSkins directly
    private var groupedSkins: [(String, [DeltaSkinProtocol])] {
        let grouped = Dictionary(grouping: manager.loadedSkins) { skin in
            skin.gameType.systemIdentifier?.fullName ?? skin.gameType.rawValue
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // Create an ordered list that matches the visual grouping
    private var orderedSkins: [DeltaSkinProtocol] {
        groupedSkins.flatMap { _, consoleSkins in consoleSkins }
    }

    /// Custom transition for section content
    private var sectionTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -20)),
            removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -20))
        )
    }

    var body: some View {
        Group {
            switch (isLoading, error, manager.loadedSkins.isEmpty) {
            case (true, _, _):
                ProgressView("Loading skins...")
                    .backgroundStyle(.blendMode(.darken))
            case (_, let error?, _):
                ErrorView(error: error)
            case (_, _, true):
                if #available(iOS 17.0, tvOS 17.0, *) {
                    ContentUnavailableView(
                        "No Skins Found",
                        systemImage: "gamecontroller",
                        description: Text("Add skins to get started")
                    )
                } else {
                    // Fallback on earlier versions
                    Text("No Skins Found")
                    Text("Add skins to get started")
                }
            default:
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(groupedSkins, id: \.0) { consoleName, consoleSkins in
                            VStack(alignment: .leading, spacing: 12) {
                                // Section header with disclosure button
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        toggleSection(consoleName)
                                    }
                                } label: {
                                    HStack {
                                        Text(consoleName)
                                            .font(.title2)
                                            .fontWeight(.bold)

                                        Spacer()

                                        Image(systemName: isExpanded(consoleName) ? "chevron.down" : "chevron.right")
                                            .foregroundStyle(.secondary)
                                            .font(.headline)
                                            .rotationEffect(.degrees(isExpanded(consoleName) ? 0 : -90))
                                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded(consoleName))
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)

                                // Grid of skins for this console
                                if isExpanded(consoleName) {
                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(consoleSkins, id: \.identifier) { skin in
                                            NavigationLink {
                                                PagedSkinTestView(
                                                    skins: orderedSkins,
                                                    initialIndex: orderedSkins.firstIndex(where: { $0.identifier == skin.identifier }) ?? 0
                                                )
                                            } label: {
                                                SkinPreviewCell(skin: skin, manager: manager)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .transition(sectionTransition)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.systemGroupedBackground)
        .task {
            await loadSkins()
            initializeSectionStates()
        }
        .onChange(of: expandedSections) { newValue in
            expandedSectionsString = newValue.sorted().joined(separator: ",")
        }
    }

    /// Initialize section states to expanded by default
    private func initializeSectionStates() {
        // Convert stored string to Set
        let storedSections = Set(expandedSectionsString.split(separator: ",").map(String.init))

        // If we have stored states, use them
        if !expandedSectionsString.isEmpty {
            expandedSections = storedSections
        } else {
            // Otherwise, initialize all sections as expanded
            expandedSections = Set(groupedSkins.map { $0.0 })
            // Update stored string
            expandedSectionsString = expandedSections.sorted().joined(separator: ",")
        }
    }

    /// Toggle the expanded state of a section
    private func toggleSection(_ consoleName: String) {
        if expandedSections.contains(consoleName) {
            expandedSections.remove(consoleName)
        } else {
            expandedSections.insert(consoleName)
        }
    }

    /// Check if a section is expanded
    private func isExpanded(_ consoleName: String) -> Bool {
        expandedSections.contains(consoleName)
    }

    private func loadSkins() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await manager.availableSkins()  // This will update loadedSkins
        } catch {
            self.error = error
        }
    }

    private func index(of skin: DeltaSkinProtocol) -> Int {
        manager.loadedSkins.firstIndex(where: { $0.identifier == skin.identifier }) ?? 0
    }
}

/// Preview cell for a skin with rubber-like design
private struct SkinPreviewCell: View {
    let skin: DeltaSkinProtocol
    let manager: DeltaSkinManager
    @State private var showingDeleteAlert = false
    @State private var deleteError: Error?
    @State private var showingErrorAlert = false
    #if !os(tvOS)
    @State private var showingShareSheet = false
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // Rubber-like colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.85)
    }

    private var innerShadowColor: Color {
        colorScheme == .dark ? .black : Color(white: 0.7)
    }

    private var embossHighlightColor: Color {
        colorScheme == .dark ? Color(white: 0.25) : Color.white
    }

    private var previewTraits: DeltaSkinTraits {
        // Try current device first
        let device: DeltaSkinDevice = horizontalSizeClass == .regular ? .ipad : .iphone
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: .portrait)

        // Return first supported configuration
        if skin.supports(traits) {
            return traits
        }

        // Try alternate device
        let altDevice: DeltaSkinDevice = device == .ipad ? .iphone : .ipad
        let altTraits = DeltaSkinTraits(device: altDevice, displayType: .standard, orientation: .portrait)

        if skin.supports(altTraits) {
            return altTraits
        }

        // Fallback to edge to edge
        return DeltaSkinTraits(device: device, displayType: .edgeToEdge, orientation: .portrait)
    }

    var body: some View {
        ZStack {
            // Preview content with disabled interaction
            content
                .allowsHitTesting(false)  // Disable interaction on the preview content

            // Transparent overlay to capture context menu
            Color.clear
                .contentShape(Rectangle())  // Make entire area tappable
        }
        .contextMenu {
            #if !os(tvOS)
            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            #endif

            if manager.isDeletable(skin) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Skin?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await manager.deleteSkin(skin.identifier)
                    } catch {
                        deleteError = error
                        showingErrorAlert = true
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(skin.name)'? This cannot be undone.")
        }
        .alert("Delete Error", isPresented: $showingErrorAlert, presenting: deleteError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        #if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [skin.fileURL])
        }
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview
            PreviewContainer {
                DeltaSkinView(skin: skin, traits: previewTraits, inputHandler: .init(emulatorCore: nil))
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
                    Label(skin.gameType.systemIdentifier?.fullName ?? skin.gameType.rawValue,
                          systemImage: "gamecontroller")
                        .lineLimit(1)

                    Spacer()

                    DeviceIndicators(skin: skin)
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
                backgroundColor

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
                .stroke(innerShadowColor, lineWidth: 2)
                .blur(radius: 2)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 2)
                )
                .blendMode(.overlay)
        }
        .overlay {
            // Inner shadow for depth
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(embossHighlightColor, lineWidth: 1)
                .blur(radius: 1)
                .opacity(0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        .padding(2)
    }
}

/// Container for preview image with rubber-like styling
public struct PreviewContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .aspectRatio(2/3, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(10)
            .overlay {
                // Screen glare effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(10)
            }
    }
}

/// Device support indicators
private struct DeviceIndicators: View {
    let skin: DeltaSkinProtocol

    var body: some View {
        HStack(spacing: 4) {
            if skin.supports(DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait)) {
                Image(systemName: "iphone")
            }
            if skin.supports(DeltaSkinTraits(device: .ipad, displayType: .standard, orientation: .portrait)) {
                Image(systemName: "ipad")
            }
        }
    }
}

/// Error view
private struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("Error Loading Skins")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Helper Extensions
internal extension Color {
    #if os(tvOS)
    static let systemGroupedBackground = Color(uiColor: .darkGray)
    static let secondarySystemGroupedBackground = Color(uiColor: .lightGray)
    #else
    static let systemGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    #endif
}

// Add this new view:
private struct PagedSkinTestView: View {
    let skins: [DeltaSkinProtocol]
    let initialIndex: Int

    @State private var selectedIndex: Int

    init(skins: [DeltaSkinProtocol], initialIndex: Int) {
        self.skins = skins
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(skins.enumerated()), id: \.element.identifier) { index, skin in
                DeltaSkinTestView(skin: skin)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(selectedIndex + 1) of \(skins.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if !os(tvOS)
/// ShareSheet wrapper for UIActivityViewController
public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    
    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
