import SwiftUI
import PVLogging
import UniformTypeIdentifiers

/// View for listing available skins

/// Grid view for browsing and selecting skins
public struct DeltaSkinListView: View {
    @ObservedObject var manager: DeltaSkinManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingFullscreenPreview = false
    @State private var traits: DeltaSkinTraits?
    @State private var screenAspectRatio: CGFloat?
    @State private var availableSkins: [any DeltaSkinProtocol] = []
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
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SkinCatalogBrowserView()) {
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
            .onAppear {
                // Use manager's loadedSkins directly if available
                if !manager.loadedSkins.isEmpty {
                    availableSkins = manager.loadedSkins
                } else {
                    // Trigger load - SkinGridView will handle the actual loading
                    // and loadedSkins will be updated asynchronously
                    Task {
                        do {
                            // This will trigger scanForSkins if needed
                            // The loadedSkins will be updated asynchronously on main thread
                            _ = try await manager.availableSkins(forceRescan: false)
                            // Update availableSkins after a brief delay to allow loadedSkins to update
                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                            await MainActor.run {
                                availableSkins = manager.loadedSkins
                            }
                        } catch {
                            ELOG("Failed to load skins: \(error)")
                        }
                    }
                }
            }
            .onChange(of: manager.loadedSkins.count) { _ in
                // Update availableSkins when manager's loadedSkins changes
                availableSkins = manager.loadedSkins
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
        #endif
            .retroAlert("Import Error",
                        message: importError?.localizedDescription ?? "Failed to import skin",
                        isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            }
    }

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

        // IMPORTANT: Accept archive-conforming variants (these are actually ZIPs with custom extensions)
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
