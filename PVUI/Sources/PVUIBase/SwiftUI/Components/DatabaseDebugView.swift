import SwiftUI
import RealmSwift
import PVRealm
import PVLogging

// MARK: - Conditional DisclosureGroup

/// A wrapper that provides a DisclosureGroup on iOS and a custom implementation on tvOS
struct ConditionalDisclosureGroup<Label: View, Content: View>: View {
    @Binding var isExpanded: Bool
    let label: () -> Label
    let content: () -> Content
    
    init(isExpanded: Binding<Bool>, @ViewBuilder label: @escaping () -> Label, @ViewBuilder content: @escaping () -> Content) {
        self._isExpanded = isExpanded
        self.label = label
        self.content = content
    }
    
    // Convenience initializer for string labels
    init(_ titleKey: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) where Label == Text {
        self._isExpanded = isExpanded
        self.label = { Text(titleKey) }
        self.content = content
    }
    
    var body: some View {
        #if os(tvOS)
        VStack(alignment: .leading) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    label()
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .focusable(true)
            if isExpanded {
                content()
                    .padding(.leading)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        #else
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: content,
            label: label
        )
        #endif
    }
}

public struct DatabaseDebugView: View {
    @State private var realm: Realm?
    @State private var games: Results<PVGame>?
    @State private var systems: Results<PVSystem>?
    @State private var cores: Results<PVCore>?
    
    @State private var showGames = false
    @State private var showSystems = false
    @State private var showCores = false
    
    private var gamesSection: some View {
        ConditionalDisclosureGroup(
            isExpanded: $showGames,
            label: {
                HStack {
                    Image(systemName: "gamecontroller")
                    Text("Games (\(games?.count ?? 0))")
                }
            }, content: {
                if let games = games {
                    ForEach(Array(games), id: \.id) { game in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.title)
                                .font(.headline)
                            
                            Text("System: \(game.system?.name ?? "Unknown")")
                                .font(.subheadline)
                            
                            if let userPreferredCoreID = game.userPreferredCoreID {
                                Text("User Preferred Core: \(userPreferredCoreID)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("MD5: \(game.md5Hash)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No games found")
                        .foregroundColor(.gray)
                }
            }
        )
    }
    
    private var systemsSection: some View {
        ConditionalDisclosureGroup(
            isExpanded: $showSystems,
            label: {
                HStack {
                    Image(systemName: "cpu")
                    Text("Systems (\(systems?.count ?? 0))")
                }
            }, content: {
                if let systems = systems {
                    ForEach(Array(systems), id: \.identifier) { system in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(system.name)
                                .font(.headline)
                            
                            Text("ID: \(system.identifier)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            if let userPreferredCoreID = system.userPreferredCoreID {
                                Text("User Preferred Core: \(userPreferredCoreID)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            ConditionalDisclosureGroup("Associated Cores (\(system.cores.count))", isExpanded: .constant(false)) {
                                ForEach(Array(system.cores), id: \.identifier) { core in
                                    Text(core.projectName)
                                        .font(.caption)
                                        .padding(.leading)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No systems found")
                        .foregroundColor(.gray)
                }
            }
        )
    }
    
    private var coresSection: some View {
        ConditionalDisclosureGroup(
            isExpanded: $showCores,
            label: {
                HStack {
                    Image(systemName: "memorychip")
                    Text("Cores (\(cores?.count ?? 0))")
                }
            }, content: {
                if let cores = cores {
                    ForEach(Array(cores), id: \.identifier) { core in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(core.projectName)
                                .font(.headline)
                            
                            Text("ID: \(core.identifier)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            if core.disabled {
                                Text("DISABLED")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Text("Has Core Class: \(core.hasCoreClass ? "Yes" : "No")")
                                .font(.caption)
                            
                            ConditionalDisclosureGroup("Supported Systems (\(core.supportedSystems.count))", isExpanded: .constant(false)) {
                                ForEach(Array(core.supportedSystems), id: \.identifier) { system in
                                    Text(system.name)
                                        .font(.caption)
                                        .padding(.leading)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No cores found")
                        .foregroundColor(.gray)
                }
            }
        )
    }
    
    public var body: some View {
        NavigationView {
            List {
                SwiftUI.Section(header: Text("Database Entities")) {
                    gamesSection
                    systemsSection
                    coresSection
                }
            }
            .navigationTitle("Database Debug")
            .onAppear {
                loadData()
            }
            .refreshable {
                loadData()
            }
        }
    }
    
    private func loadData() {
        do {
            realm = try Realm()
            if let realm = realm {
                games = realm.objects(PVGame.self).sorted(byKeyPath: "title")
                systems = realm.objects(PVSystem.self).sorted(byKeyPath: "name")
                cores = realm.objects(PVCore.self).sorted(byKeyPath: "projectName")
                ILOG("DatabaseDebugView: Loaded \(games?.count ?? 0) games, \(systems?.count ?? 0) systems, and \(cores?.count ?? 0) cores")
            }
        } catch {
            ELOG("DatabaseDebugView: Failed to open Realm: \(error)")
        }
    }
}

#if DEBUG
#Preview {
    DatabaseDebugView()
}
#endif
