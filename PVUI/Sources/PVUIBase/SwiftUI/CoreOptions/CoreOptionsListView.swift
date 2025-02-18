import Combine
import PVCoreBridge
import PVLibrary
import PVPrimitives
import PVSupport
import PVThemes
import RealmSwift
import SwiftUI
import PVLogging
import AsyncAlgorithms

/// Struct to hold essential system data
private struct SystemDisplayData: Identifiable {
    /// The identifier of the system
    let id: String
    /// The name of the system
    let name: String
    /// The icon name of the system
    let iconName: String
}

fileprivate extension PVSystem {
    /// Get the icon name from the identifier
    var iconName: String {
        // Take the last segment of identifier seperated by .
        return self.identifier.components(separatedBy: ".").last?.lowercased() ?? "prov_snes_icon"
    }
}

/// A simple struct to hold core information for the list
private struct CoreListItem: Identifiable {
    /// The identifier of the core
    let id: String
    /// The name of the core
    let name: String
    /// The class of the core
    let coreClass: CoreOptional.Type
    /// The number of options in the core
    let optionCount: Int
    /// The systems that the core supports
    let systems: [SystemDisplayData]

    /// Initialize the core list item
    /// - Parameter core: The core to initialize the list item from
    @MainActor
    init?(core: PVCore) {
        let id = core.identifier
        let name = core.projectName
        let principleClass = core.principleClass
        self.id = id
        self.name = name

        ILOG("CoreOptions: Checking for options in \(principleClass)")
        guard let coreClass = NSClassFromString(principleClass) as? CoreOptional.Type else {
            ILOG("CoreOptions: core.principleClass not a valid CoreOptional subclass: \(core.principleClass)")
            return nil
        }

        DLOG("CoreOptions: \(principleClass) loading options...")
        self.coreClass = coreClass

        let optionCount = CoreListItem.countOptions(in: self.coreClass.options)
        self.optionCount = optionCount

        ILOG("CoreOptions: Found \(optionCount) options for core \(id)")
        let isAppStore = AppState.shared.isAppStore

        // Process systems synchronously since we're already in an async context
        var systemsData: [SystemDisplayData] = []
        for system in core.supportedSystems {
            if isAppStore && system.appStoreDisabled && !Defaults[.unsupportedCores] {
                DLOG("CoreOptions: Hiding options for system \(system.identifier) as it's app store disabled")
                continue
            }
            systemsData.append(SystemDisplayData(id: system.identifier, name: system.name, iconName: system.iconName))
        }

        self.systems = systemsData
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
    /// The cores in the database
    @ObservedResults(PVCore.self) private var cores
    /// The text in the search bar
    @State private var searchText = ""
    /// Whether to show unsupported cores
    @Default(.unsupportedCores) private var unsupportedCores
    /// The items in the list
    @State private var coreItems: [CoreListItem] = []
    /// The theme manager
    @ObservedObject private var themeManager = ThemeManager.shared

    /// The body of the view
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
            /// Load the core items
            DLOG("CoreOptions: Loading core items for \(cores.count) cores")
            await loadCoreItems()
        }
    }

    /// Load the core items
    private func loadCoreItems() async {
        ILOG("CoreOptions: Loading core items for \(cores.count) cores")
        var items: [CoreListItem] = []

        // Process each core sequentially
        for core in cores {
            DLOG("CoreOptions: Processing core: \(core.identifier) (\(core.principleClass))")
            if let item = await CoreListItem(core: core), item.optionCount > 0 {
                DLOG("CoreOptions: Successfully created item for core: \(core.identifier)")
                items.append(item)
            } else {
                DLOG("CoreOptions: Failed to create item for core or was empty: \(core.identifier)")
            }
        }

        ILOG("CoreOptions: Loaded \(items.count) items")
        coreItems = items
    }
}

/// View for a single core item in the list
private struct CoreListItemView: View {
    /// The item in the list
    let item: CoreListItem
    /// The theme manager
    @ObservedObject private var themeManager = ThemeManager.shared

    /// The body of the view
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
        #if !os(tvOS)
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(themeManager.currentPalette.menuHeaderText.swiftUIColor, lineWidth: 3)
        )
    }
}

/// Updated SearchBar component
private struct SearchBar: View {
    /// The text in the search bar
    @Binding var text: String
    /// If in a search
    @Binding var isSearching: Bool

    /// The body of the view
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
            #if !os(tvOS)
            .background(Color(.systemGray6))
            #endif
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
