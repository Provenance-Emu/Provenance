import SwiftUI
import PVCoreBridge
import PVLibrary
import PVThemes

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
        
    @Default(.unsupportedCores) private var unsupportedCores
    
    init(id: String, name: String, coreClass: CoreOptional.Type, optionCount: Int, systems: [SystemDisplayData]) {
        self.id = id
        self.name = name
        self.coreClass = coreClass
        self.optionCount = optionCount
        self.systems = systems
    }

    init(core: PVCore) {
        self.id = core.identifier
        self.name = core.projectName
        self.coreClass = NSClassFromString(core.principleClass) as! CoreOptional.Type
        self.optionCount = CoreListItem.countOptions(in: self.coreClass.options)

        let isAppStore = AppState.shared.isAppStore
        
        let systems = core.supportedSystems.compactMap { system -> SystemDisplayData? in
            /// Hide system if it's app store disabled and we're in app store mode with unsupported cores off
            if isAppStore && system.appStoreDisabled && !Defaults[.unsupportedCores] {
                return nil
            }
            return SystemDisplayData(id: system.identifier, name: system.name, iconName: system.iconName)
        }
        self.systems = Array(systems)
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
    @StateObject private var viewModel = CoreOptionsViewModel()
    @State private var searchText: String = ""

    private var filteredCoreItems: [CoreListItem] {
        let allItems = viewModel.availableCores.compactMap { core -> CoreListItem? in
            guard let coreClass = NSClassFromString(core.principleClass) as? CoreOptional.Type else {
                return nil
            }

            let options: [CoreOption]
            if let subCoreClass = coreClass as? SubCoreOptional.Type {
                options = subCoreClass.options(forSubcoreIdentifier: core.identifier, systemName: core.supportedSystems.map { $0.identifier }.joined(separator: ",")) ?? subCoreClass.options
            } else {
                options = coreClass.options
            }

            guard hasValidOptions(in: options) else {
                return nil
            }

            return CoreListItem(core: core)
        }

        /// Filter based on search text
        guard !searchText.isEmpty else { return allItems }
        let lowercasedSearch = searchText.lowercased()

        return allItems.filter { item in
            /// Check core name
            if item.name.lowercased().contains(lowercasedSearch) {
                return true
            }

            /// Check core identifier
            if item.id.lowercased().contains(lowercasedSearch) {
                return true
            }

            /// Check supported systems
            if let core = viewModel.availableCores.first(where: { $0.identifier == item.id }) {
                return core.supportedSystems.contains { system in
                    system.identifier.lowercased().contains(lowercasedSearch) ||
                    system.name.lowercased().contains(lowercasedSearch)
                }
            }

            return false
        }
    }

    /// Recursively check if there are any meaningful options in the array
    private func hasValidOptions(in options: [CoreOption]) -> Bool {
        for option in options {
            switch option {
            case .group(_, let subOptions):
                // Recursively check group's options
                if hasValidOptions(in: subOptions) {
                    return true
                }
            case .bool, .string, .enumeration, .range, .rangef, .multi:
                // Any non-group option is considered valid
                return true
            }
        }
        return false
    }

    var body: some View {
        #if os(tvOS)
        VStack {
            // Search field at the top
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search cores, systems, or options", text: $searchText)
                    .padding(8)
                    .cornerRadius(8)
            }
            .padding()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredCoreItems) { item in
                        CoreListItemView(item: item)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Core Options")
        #else
        List {
            ForEach(filteredCoreItems) { item in
                CoreListItemView(item: item)
            }
        }
        .searchable(text: $searchText, prompt: "Search cores, systems, or options")
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Core Options")
        #endif
    }
}

/// View for a single core item in the list
private struct CoreListItemView: View {
    let item: CoreListItem
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationLink(destination: CoreOptionsDetailView(coreClass: item.coreClass, title: item.name)) {
            VStack(alignment: .leading, spacing: 8) {
                // Core name
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(Color.primary)

                // Supported systems
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

                // Number of options
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
