import Combine
import PVCoreBridge
import PVLibrary
import PVPrimitives
import PVSupport
import PVThemes
import RealmSwift
import SwiftUI

/// Struct to hold essential system data
private struct SystemDisplayData: Identifiable {
    let id: String
    let name: String
    let iconName: String
}

fileprivate extension PVSystem {
    var iconName: String {
        // Take the last segment of identifier seperated by .
        return self.identifier.components(separatedBy: ".").last?.lowercased() ?? "prov_snes_icon"
    }
}

/// A simple struct to hold core information for the list
private struct CoreListItem: Identifiable {
    let id: String
    let name: String
    let coreClass: CoreOptional.Type
    let optionCount: Int
    let systems: [SystemDisplayData]

    init(core: PVCore) async {
        self.id = core.identifier
        self.name = core.projectName
        self.coreClass = NSClassFromString(core.principleClass) as! CoreOptional.Type
        self.optionCount = CoreListItem.countOptions(in: self.coreClass.options)

        let isAppStore = await AppState.shared.isAppStore
        self.systems = core.supportedSystems.compactMap { system in
            /// Hide system if it's app store disabled and we're in app store mode with unsupported cores off
            if isAppStore && system.appStoreDisabled && !Defaults[.unsupportedCores] {
                return nil
            }
            return SystemDisplayData(id: system.identifier, name: system.name, iconName: system.iconName)
        }
    }

    /// Recursively count all options, including those in groups
    private static func countOptions(in options: [CoreOption]) -> Int {
        options.reduce(0) { count, option in
            switch option {
            case .group(_, let subOptions):
                return count + countOptions(in: subOptions)
            case .bool, .string, .enumeration, .range, .rangef, .multi:
                return count + 1
            }
        }
    }
}

/// View that lists all cores that implement CoreOptional
struct CoreOptionsListView: View {
    @ObservedResults(PVCore.self) private var cores
    @State private var searchText = ""
    @Default(.unsupportedCores) private var unsupportedCores
    @State private var coreItems: [CoreListItem] = []

    var body: some View {
        List {
            ForEach(coreItems) { item in
                NavigationLink {
                    CoreOptionsDetailView(coreClass: item.coreClass, title: item.name)
                } label: {
                    CoreListItemView(item: item)
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Core Options")
        .task {
            await loadCoreItems()
        }
    }

    private func loadCoreItems() async {
        var items: [CoreListItem] = []
        for core in cores {
            let item = await CoreListItem(core: core)
            items.append(item)
        }
        coreItems = items
    }
}

/// View for a single core item in the list
private struct CoreListItemView: View {
    let item: CoreListItem
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.headline)
                .foregroundColor(Color.primary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(item.systems) { system in
                    HStack {
                        Image(system.iconName, bundle: PVUIBase.BundleLoader.myBundle)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .tint(Color.primary)

                        Text(system.name)
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                }
            }

            Text("\(item.optionCount) option\(item.optionCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(Color.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(themeManager.currentPalette.menuHeaderText.swiftUIColor, lineWidth: 3)
        )
    }
}

/// Updated SearchBar component
private struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search cores...", text: $text, onEditingChanged: { editing in
                    isSearching = editing
                })
                .padding(8)

                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)

            if isSearching {
                Button("Cancel") {
                    text = ""
                    isSearching = false
                    /// Dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: isSearching)
    }
}
