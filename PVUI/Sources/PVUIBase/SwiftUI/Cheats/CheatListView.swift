import SwiftUI
import PVPrimitives

/// Main view for displaying and managing cheat codes
public struct CheatListView<Driver: CheatDriver>: View {
    @StateObject private var driver: Driver
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingImportSheet = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(driver: Driver) {
        _driver = StateObject(wrappedValue: driver)
    }

    private var filteredCheats: [Driver.Entry] {
        if searchText.isEmpty {
            return driver.cheats
        }
        return driver.cheats.filter { cheat in
            cheat.title.localizedCaseInsensitiveContains(searchText) ||
            cheat.code.localizedCaseInsensitiveContains(searchText) ||
            driver.gameTitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        List {
            ForEach(filteredCheats) { cheat in
                CheatRowView(cheat: cheat) { action in
                    switch action {
                    case .toggle:
                        driver.toggleCheat(cheat.id)
                    case .delete:
                        driver.deleteCheat(cheat.id)
                    case .edit:
                        // TODO: Implement edit
                        break
                    }
                }
                #if os(iOS)
                .swipeActions(edge: .leading) {
                    Button {
                        driver.toggleCheat(cheat.id)
                    } label: {
                        Label("Toggle", systemImage: "power")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        driver.deleteCheat(cheat.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #endif
            }
        }
        .searchable(text: $searchText, prompt: "Search cheats")
        .navigationTitle("Cheat Codes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Cheat", systemImage: "plus")
                }
            }

            #if os(iOS)
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingImportSheet = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                AddCheatView<Driver>(
                    driver: driver,
                    onSave: { newCheat in
                        driver.addCheat(newCheat)
                    }
                )
            }
            #if os(iOS)
            .presentationDragIndicator(.visible)
            #endif
        }
        #if os(iOS)
        .sheet(isPresented: $showingImportSheet) {
            NavigationStack {
                ImportCheatView<Driver>(
                    driver: driver,
                    onImport: { newCheats in
                        newCheats.forEach { driver.addCheat($0) }
                    }
                )
            }
            .presentationDragIndicator(.visible)
        }
        #endif
    }
}

struct CheatRowView<Entry: CheatEntry>: View {
    let cheat: Entry
    let onAction: (CheatAction) -> Void

    enum CheatAction {
        case toggle
        case delete
        case edit
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Toggle(isOn: .init(
                    get: { cheat.enabled },
                    set: { _ in onAction(.toggle) }
                )) {
                    Text(cheat.title)
                        .font(.headline)
                }

                Spacer()

                #if os(tvOS)
                Button {
                    onAction(.delete)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                #endif
            }

            Text(cheat.code)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(cheat.type.formatDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        #if os(tvOS)
        .buttonStyle(.card)
        #endif
    }
}

#Preview {
    NavigationStack {
        CheatListView(driver: MockCheatDriver.shared())
    }
}
