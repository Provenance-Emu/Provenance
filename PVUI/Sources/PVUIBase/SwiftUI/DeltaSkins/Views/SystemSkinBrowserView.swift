import SwiftUI
import PVPrimitives

/// View for browsing and selecting skins for all systems
public struct SystemSkinBrowserView: View {
    @StateObject private var skinManager = DeltaSkinManager.shared
    @State private var systemSkinCounts: [SystemIdentifier: Int] = [:]
    @State private var isLoading = true

    @State private var selectedSystem: SystemIdentifier?
    @State private var showingSystemSelection = false

    public init() {}

    public var body: some View {
        List {
            SwiftUI.Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    // Systems with available skins
                    ForEach(supportedSystems, id: \.self) { system in
                        systemRow(system)
                    }
                }
            } header: {
                Text("Controller Skins")
            }

            SwiftUI.Section {
                Button(action: {
                    // Show skin import UI
                }) {
                    Label("Import Skin", systemImage: "square.and.arrow.down")
                }

                Button(action: {
                    Task {
                        await skinManager.reloadSkins()
                        await loadSkinCounts()
                    }
                }) {
                    Label("Refresh Skins", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Controller Skins")
        .onAppear {
            loadSkinCounts()
        }
        .sheet(isPresented: $showingSystemSelection) {
            if let system = selectedSystem {
                SystemSkinSelectionView(system: system)
            }
        }
    }

    private func systemRow(_ system: SystemIdentifier) -> some View {
        let skinCount = systemSkinCounts[system] ?? 0

        return Button(action: {
            selectedSystem = system
            showingSystemSelection = true
        }) {
            HStack {
                Text(system.fullName)

                Spacer()

                Text("\(skinCount) \(skinCount == 1 ? "skin" : "skins")")
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var supportedSystems: [SystemIdentifier] {
        systemSkinCounts.filter { $0.value > 0 }.keys.sorted()
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
}
