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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
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
            .onAppear {
                // Use manager's loadedSkins directly if available, otherwise load once
                if !manager.loadedSkins.isEmpty {
                    availableSkins = manager.loadedSkins
                } else {
                    Task {
                        do {
                            availableSkins = try await manager.availableSkins(forceRescan: false)
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
            .retroAlert("Import Error",
                        message: importError?.localizedDescription ?? "Failed to import skin",
                        isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
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
