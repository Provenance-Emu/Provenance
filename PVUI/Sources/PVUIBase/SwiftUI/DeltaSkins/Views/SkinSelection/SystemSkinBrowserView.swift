import SwiftUI
import PVPrimitives
import PVLogging
import UniformTypeIdentifiers
#if canImport(SafariServices)
import SafariServices
#endif

/// View for browsing and selecting skins for all systems with retrowave styling
public struct SystemSkinBrowserView: View {
    // MARK: - Properties

    @ObservedObject private var skinManager = DeltaSkinManager.shared
    @State private var systemSkinCounts: [SystemIdentifier: Int] = [:]
    @State private var isLoading = true
    @State private var loadingProgress: Double = 0
    /// Drops a system tally when a newer scan has already been requested.
    @State private var skinListGeneration = 0

    // Environment properties
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // UI state
    @State private var showingDocumentPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?
    @State private var importingFiles = false
    @State private var importProgress: Double = 0

    public init() {}

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        if isLoading {
                            loadingView
                        } else if supportedSystems.isEmpty {
                            emptyStateView
                        } else {
                            systemsGridView

                            // Browse online catalog (prominently on tvOS since no file picker)
                            catalogBrowsePromo

                            // DeltaStyles link component
                            DeltaStylesLinkView()
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Controller Skins")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: SkinCatalogBrowserView()) {
                    Image(systemName: "arrow.down.circle")
                }
                .accessibilityLabel("Get More")
                .transaction { $0.animation = nil }
            }
            #endif

            ToolbarItem(placement: .automatic) {
                Button {
                    isLoading = true
                    Task {
                        await reloadAllSkins(forceRescan: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh skins")
                .disabled(isLoading)
                .transaction { $0.animation = nil }
            }

            #if !os(tvOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Import skin")
                .transaction { $0.animation = nil }
            }
            #endif
        }
        .onAppear {
            Task {
                await reloadAllSkins(forceRescan: false)
            }
        }
        // Navigation handled in systemSection via NavigationLink
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
        #endif
        .retroAlert("Import Error",
                    message: importError?.localizedDescription ?? "Failed to import skin",
                    isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - UI Components

    private var loadingView: some View {
        ProgressView("Loading skins")
            .tint(Color.retroCyan)
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
    }

    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                .padding(.bottom, 10)

            Text("NO SKINS FOUND")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)

            Text("Add controller skins to customize your gaming experience")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            #if os(tvOS)
            // On tvOS there is no file picker — the catalog is the only import path.
            NavigationLink(destination: SkinCatalogBrowserView()) {
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
                    Text("ADD SKINS")
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

                NavigationLink(destination: SkinCatalogBrowserView()) {
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
            #endif // os(tvOS)

            Spacer()
        }
        .frame(height: 400)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
        )
        .padding(.top, 40)
    }

    private var systemsGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 320 : 280), spacing: 20)],
            spacing: 24
        ) {
            ForEach(supportedSystems, id: \.self) { system in
                systemCard(system)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.top, 20)
    }

    private func systemCard(_ system: SystemIdentifier) -> some View {
        let skinCount = systemSkinCounts[system] ?? 0

        return NavigationLink(destination: SystemSkinSelectionView(system: system)) {
            VStack(alignment: .leading, spacing: 12) {
                // System header
                HStack {
                    Text(system.fullName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(skinCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RetroPauseInsetPillBackground(isDark: true))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Preview of selected skins for this system
                SystemSkinPreviewRow(system: system)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            }
            .background {
                RetroPausePanelBackground(isDark: true)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Promo banner that links to the remote skin catalog.
    private var catalogBrowsePromo: some View {
        NavigationLink(destination: SkinCatalogBrowserView()) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.retroCyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Get more skins")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                    #if os(tvOS)
                    Text("Browse and download skins from the community catalog")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    #else
                    Text("Browse the community skin catalog")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    #endif
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background {
                RetroPausePanelBackground(isDark: true)
            }
        }
        .retroFocusButtonStyle(showBorder: false)
        .padding(.top, 8)
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

    private var supportedSystems: [SystemIdentifier] {
        systemSkinCounts.filter { $0.value > 0 }.keys.sorted()
    }

    /// Rebuild the system list from the manager's scanned skins.
    ///
    /// `loadedSkins` is published on the main actor after the scan and can still be empty
    /// or stale when this view appears. `availableSkins()` reads the scan result directly.
    /// A newer request drops an older tally so a partial first pass cannot overwrite the full list.
    private func reloadAllSkins(forceRescan: Bool) async {
        let generation = await MainActor.run { () -> Int in
            skinListGeneration += 1
            if systemSkinCounts.isEmpty {
                isLoading = true
            }
            return skinListGeneration
        }

        if forceRescan {
            await skinManager.reloadSkins()
        }

        let allSkins = (try? await skinManager.availableSkins(forceRescan: false)) ?? []
        await updateUI(with: allSkins, generation: generation)
    }

    private func updateUI(with allSkins: [any DeltaSkinProtocol], generation: Int) async {

        // Tally skins by their skinLayoutGroup (handles families like sega-md, gb, pce, psx…)
        var groupCounts: [String: Int] = [:]
        var skinIdsByGroup: [String: Set<String>] = [:]
        for skin in allSkins {
            let group = skin.gameType.skinLayoutGroup
            groupCounts[group, default: 0] += 1
            skinIdsByGroup[group, default: []].insert(skin.identifier)
        }

        /// Catalog-derived overrides keyed by skin identifier so we can credit a
        /// misconfigured skin to its true system family (for example a SEGA SG-1000
        /// skin whose `info.json` says GBA still appears under SG-1000).
        let overrideCodes = await SkinSystemOverrideRegistry.shared.overrideCodesByIdentifier(for: allSkins)

        // Map each SystemIdentifier to its layout-group count so that family members
        // (e.g. Genesis / Sega CD / 32X) all show the combined skin count.
        var counts: [SystemIdentifier: Int] = [:]
        for system in SystemIdentifier.allCases {
            guard let gameType = DeltaSkinGameType(systemIdentifier: system) else { continue }
            let group = gameType.skinLayoutGroup
            var matchingSkinIds = skinIdsByGroup[group] ?? []

            /// Add any skins whose override codes intersect this system's catalog
            /// codes (direct + layout-group siblings) but whose declared
            /// `skinLayoutGroup` doesn't already include them.
            let requestedCodes = Set(system.relatedSkinCatalogSystemCodes)
            if !requestedCodes.isEmpty {
                for (skinId, codes) in overrideCodes where !codes.isDisjoint(with: requestedCodes) {
                    matchingSkinIds.insert(skinId)
                }
            }

            if !matchingSkinIds.isEmpty {
                counts[system] = matchingSkinIds.count
            }
        }

        // Final update. Ignore this tally when a newer load has already started.
        await MainActor.run {
            guard generation == self.skinListGeneration else { return }
            self.systemSkinCounts = counts
            self.loadingProgress = 1.0
            withAnimation(.easeOut(duration: 0.3)) {
                self.isLoading = false
            }
        }
    }

    private func importSkins(from urls: [URL]) async throws {
        await MainActor.run {
            importingFiles = true
            importProgress = 0
        }

        for (index, url) in urls.enumerated() {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                ELOG("Failed to start accessing security-scoped resource")
                throw DeltaSkinError.accessDenied
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Import the skin
            try await skinManager.importSkin(from: url)

            // Update progress
            let progress = Double(index + 1) / Double(urls.count)
            await MainActor.run {
                importProgress = progress
            }
        }

        // Reload after all imports
        await reloadAllSkins(forceRescan: false)

        await MainActor.run {
            importingFiles = false
        }
    }
}

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
