/// Cheats tab for the Provenance Companion app.
///
/// Reads the `shared-cheats.json` file written by the main Provenance app into
/// the shared App Group container (`group.org.provenance-emu.provenance`).
/// Guarded behind the `cheatLibrary` IAP: users who have not purchased see a
/// paywall prompt pointing to the store sheet.

import SwiftUI
import StoreKit

// MARK: - Companion cheat entry (mirrors SharedCheatEntry in PVLibrary)

/// A Codable mirror of `SharedCheatEntry` from PVLibrary.
/// Kept self-contained in the companion so it doesn't need a PVLibrary dependency.
private struct CompanionCheatEntry: Codable, Identifiable {
    let id: UUID
    let name: String
    let code: String
    let format: String
    let systemName: String
    let gameName: String
    let addedDate: Date
}

// MARK: - App Group cheat reader

private enum CompanionCheatReader {
    static let appGroupID = "group.org.provenance-emu.provenance"
    static let fileName   = "shared-cheats.json"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func loadAll() -> [CompanionCheatEntry] {
        guard
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return [] }
        let url = container.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([CompanionCheatEntry].self, from: data)) ?? []
    }
}

// MARK: - CheatsTabView

struct CheatsTabView: View {
    @Environment(DriverStoreManager.self) private var storeManager
    @State private var entries: [CompanionCheatEntry] = []
    @State private var showingStore = false

    var body: some View {
        NavigationStack {
            Group {
                if !storeManager.hasAccess(to: .cheatLibrary) {
                    paywallView
                } else if entries.isEmpty {
                    ContentUnavailableView(
                        String(localized: "cheats.empty.title"),
                        systemImage: "doc.on.clipboard",
                        description: Text("cheats.empty.description")
                    )
                } else {
                    cheatList
                }
            }
            .navigationTitle(String(localized: "tab.cheats"))
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if storeManager.hasAccess(to: .cheatLibrary) {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            entries = CompanionCheatReader.loadAll()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingStore) {
            DriverStoreView()
        }
        .task {
            await storeManager.loadProducts()
            if storeManager.hasAccess(to: .cheatLibrary) {
                entries = CompanionCheatReader.loadAll()
            }
        }
    }

    // MARK: - Subviews

    private var cheatList: some View {
        List(entries) { entry in
            CheatEntryRow(entry: entry)
        }
        .listStyle(.insetGrouped)
    }

    private var paywallView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("cheats.paywall.title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("cheats.paywall.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingStore = true
            } label: {
                Label("cheats.paywall.unlock_button", systemImage: "lock.open.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cheat Entry Row

private struct CheatEntryRow: View {
    let entry: CompanionCheatEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(entry.format)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }

            Text(entry.code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("\(entry.gameName) · \(entry.systemName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CheatsTabView()
        .environment(DriverStoreManager())
}
