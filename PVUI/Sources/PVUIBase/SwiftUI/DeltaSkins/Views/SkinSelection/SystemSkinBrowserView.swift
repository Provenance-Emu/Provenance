import SwiftUI
import PVPrimitives
import PVLogging
import UniformTypeIdentifiers

/// View for browsing and selecting skins for all systems
public struct SystemSkinBrowserView: View {
    @StateObject private var skinManager = DeltaSkinManager.shared
    @State private var systemSkinCounts: [SystemIdentifier: Int] = [:]
    @State private var isLoading = true

    @State private var selectedSystem: SystemIdentifier?

    public init() {

    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showingDocumentPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?
    
    // Dynamic grid sizing based on size class
    private var columns: [GridItem] {
        let minWidth: CGFloat = horizontalSizeClass == .regular ? 200 : 160
        return [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
    }
    
    public var body: some View {
        List {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading skins...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if supportedSystems.isEmpty {
                    if #available(iOS 17.0, tvOS 17.0, *) {
                        ContentUnavailableView(
                            "No Skins Found",
                            systemImage: "gamecontroller",
                            description: Text("Add skins to get started")
                        )
                        .padding()
                    } else {
                        // Fallback on earlier versions
                        VStack {
                            Text("No Skins Found")
                                .font(.headline)
                            Text("Add skins to get started")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                } else {
                    ForEach(supportedSystems, id: \.self) { system in
                        systemSection(system)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Controller Skins")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await skinManager.reloadSkins()
                        await loadSkinCounts()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadSkins()
            loadSkinCounts()
        }
        // Navigation handled in systemSection via NavigationLink
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

    private func systemSection(_ system: SystemIdentifier) -> some View {
        let skinCount = systemSkinCounts[system] ?? 0
        
        return VStack(alignment: .leading, spacing: 12) {
            // Section header with NavigationLink
            NavigationLink(destination: SystemSkinSelectionView(system: system)) {
                HStack {
                    Text(system.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(skinCount) \(skinCount == 1 ? "skin" : "skins")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // Preview of selected skins for this system
            SystemSkinPreviewRow(system: system)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondarySystemGroupedBackground)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var supportedSystems: [SystemIdentifier] {
        systemSkinCounts.filter { $0.value > 0 }.keys.sorted()
    }
    
    private func loadSkins() {
        Task {
            await self.skinManager.reloadSkins()
        }
    }

    private func loadSkinCounts() {
        Task {
            isLoading = true

            // Get all available skins
            let allSkins = try await skinManager.availableSkins()

            // Group by system
            var counts: [SystemIdentifier: Int] = [:]

            for skin in allSkins {
                if let system = skin.gameType.systemIdentifier {
                    counts[system, default: 0] += 1
                }
            }

            await MainActor.run {
                self.systemSkinCounts = counts
                self.isLoading = false
            }
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
            try await skinManager.importSkin(from: url)
        }

        // Reload after all imports
        await skinManager.reloadSkins()
        await loadSkinCounts()
    }
}
