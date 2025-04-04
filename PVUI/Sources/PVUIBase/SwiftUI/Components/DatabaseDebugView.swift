import SwiftUI
import RealmSwift
import PVRealm
import PVLogging

public struct DatabaseDebugView: View {
    @State private var realm: Realm?
    @State private var games: Results<PVGame>?
    @State private var systems: Results<PVSystem>?
    @State private var cores: Results<PVCore>?
    
    @State private var showGames = false
    @State private var showSystems = false
    @State private var showCores = false
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Database Entities")) {
                    DisclosureGroup(
                        isExpanded: $showGames,
                        content: {
                            if let games = games {
                                ForEach(games, id: \.id) { game in
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
                        },
                        label: {
                            HStack {
                                Image(systemName: "gamecontroller")
                                Text("Games (\(games?.count ?? 0))")
                            }
                        }
                    )
                    
                    DisclosureGroup(
                        isExpanded: $showSystems,
                        content: {
                            if let systems = systems {
                                ForEach(systems, id: \.identifier) { system in
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
                                        
                                        DisclosureGroup("Associated Cores (\(system.cores.count))") {
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
                        },
                        label: {
                            HStack {
                                Image(systemName: "cpu")
                                Text("Systems (\(systems?.count ?? 0))")
                            }
                        }
                    )
                    
                    DisclosureGroup(
                        isExpanded: $showCores,
                        content: {
                            if let cores = cores {
                                ForEach(cores, id: \.identifier) { core in
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
                                        
                                        DisclosureGroup("Supported Systems (\(core.supportedSystems.count))") {
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
                        },
                        label: {
                            HStack {
                                Image(systemName: "memorychip")
                                Text("Cores (\(cores?.count ?? 0))")
                            }
                        }
                    )
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
