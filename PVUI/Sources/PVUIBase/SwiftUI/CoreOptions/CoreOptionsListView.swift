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
    /// Whether to show the reset confirmation alert
    @State private var showResetAllConfirmation = false
    /// Whether we're currently searching
    @State private var isSearching = false
    /// State to track if view is appearing
    @State private var hasAppeared = false
    /// State to track scroll offset
    @State private var scrollOffset: CGFloat = 0
    /// State to track if header is visible
    @State private var isHeaderVisible = true
    /// Previous scroll offset for direction detection
    @State private var previousScrollOffset: CGFloat = 0
    /// Header height when expanded
    private let expandedHeaderHeight: CGFloat = 160
    /// Header height when collapsed
    private let collapsedHeaderHeight: CGFloat = 0

    /// The body of the view
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollViewWithOffset(
                offsetChanged: { offset in
                    // Detect scroll direction
                    let scrollingDown = offset < previousScrollOffset

                    // Update header visibility based on scroll direction
                    if scrollingDown && offset < -20 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHeaderVisible = false
                        }
                    } else if !scrollingDown {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHeaderVisible = true
                        }
                    }

                    scrollOffset = offset
                    previousScrollOffset = offset
                }
            ) {
                // Add padding to account for the header
                VStack {
                    // Spacer to push content below the header
                    Spacer()
                        .frame(height: expandedHeaderHeight)

                    LazyVStack {
                        ForEach(filteredCoreItems) { item in
                            NavigationLink {
                                CoreOptionsDetailView(coreClass: item.coreClass, title: item.name)
                            } label: {
                                CoreListItemView(item: item)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .id(item.id) // Add id to help maintain identity
                        }
                    }
                    .padding(.bottom)
                }
            }
            .id("coreOptionsScrollView") // Add stable ID to ScrollView

            // Header with RetroArch note and search bar
            VStack(spacing: 8) {
                // RetroArch note
                VStack(alignment: .leading, spacing: 4) {
                    Text("Note about RetroArch Cores")
                        .font(.headline)
                        .foregroundColor(Color.primary)

                    Text("RetroArch cores may show additional options in the in-game core options menu that aren't available here due to RetroArch limitations.")
                        .font(.subheadline)
                        .foregroundColor(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)

                // Search bar
                if hasAppeared {
                    CoreSearchBar(text: $searchText, isSearching: $isSearching)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 8)
            .frame(height: isHeaderVisible ? expandedHeaderHeight : collapsedHeaderHeight)
            .opacity(isHeaderVisible ? 1 : 0)
            .background(Color(.systemBackground))
            .animation(.easeInOut(duration: 0.3), value: isHeaderVisible)
        }
        .navigationTitle("Core Options")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showResetAllConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // Delay setting hasAppeared to avoid animation issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
        .task {
            /// Load the core items
            DLOG("CoreOptions: Loading core items for \(cores.count) cores")
            await loadCoreItems()
        }
        .uiKitAlert(
            "Reset All Core Options",
            message: "Are you sure you want to reset ALL options for ALL cores to their default values? This cannot be undone.",
            isPresented: $showResetAllConfirmation
        ) {
            UIAlertAction(title: "Reset All", style: .destructive) { _ in
                resetAllCoreOptions()
                showResetAllConfirmation = false
            }

            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                showResetAllConfirmation = false
            }
        }
    }

    /// Filtered core items based on search text
    private var filteredCoreItems: [CoreListItem] {
        if searchText.isEmpty {
            return coreItems
        } else {
            return coreItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.systems.contains { system in
                    system.name.localizedCaseInsensitiveContains(searchText)
                }
            }
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

    /// Reset all options for all cores
    private func resetAllCoreOptions() {
        ILOG("CoreOptions: Resetting ALL options for ALL cores")

        // Reset options for each core
        for item in coreItems {
            DLOG("CoreOptions: Resetting options for core: \(item.id)")
            item.coreClass.resetAllOptions()
        }

        // Delete RetroArch config files
        deleteRetroArchConfigFiles()

        // Show a toast or notification that reset is complete
        #if !os(tvOS)
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowToast"),
            object: nil,
            userInfo: ["message": "All core options have been reset to defaults"]
        )
        #endif

        ILOG("CoreOptions: All core options have been reset")
    }

    /// Delete all RetroArch config files (.opt files)
    private func deleteRetroArchConfigFiles() {
        let fileManager = FileManager.default

        // Get the appropriate base directory
        #if os(tvOS)
        /// Use Caches directory on tvOS
        guard let baseURL = try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            ELOG("CoreOptions: Failed to get caches directory")
            return
        }
        #else
        /// Use Documents directory on iOS
        guard let baseURL = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            ELOG("CoreOptions: Failed to get documents directory")
            return
        }
        #endif

        // Construct the RetroArch config directory path
        let retroArchConfigURL = baseURL.appendingPathComponent("RetroArch/config", isDirectory: true)

        DLOG("CoreOptions: Looking for RetroArch config files in \(retroArchConfigURL.path)")

        // Check if the directory exists
        guard fileManager.fileExists(atPath: retroArchConfigURL.path) else {
            DLOG("CoreOptions: RetroArch config directory does not exist")
            return
        }

        // Find and delete all .opt files recursively
        do {
            /// Get all files in the directory and subdirectories
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: retroArchConfigURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles],
                errorHandler: { (url, error) -> Bool in
                    ELOG("CoreOptions: Error accessing \(url): \(error)")
                    return true
                }
            )!

            var deletedCount = 0

            /// Process each file
            for case let fileURL as URL in enumerator {
                /// Check if it's a .opt file
                if fileURL.pathExtension == "opt" {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        deletedCount += 1
                        DLOG("CoreOptions: Deleted config file: \(fileURL.lastPathComponent)")
                    } catch {
                        ELOG("CoreOptions: Failed to delete \(fileURL.path): \(error)")
                    }
                }
            }

            ILOG("CoreOptions: Deleted \(deletedCount) RetroArch config files")
        } catch {
            ELOG("CoreOptions: Error enumerating RetroArch config directory: \(error)")
        }
    }
}

/// A ScrollView that reports its content offset
struct ScrollViewWithOffset<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let offsetChanged: (CGFloat) -> Void
    let content: Content

    init(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        offsetChanged: @escaping (CGFloat) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.offsetChanged = offsetChanged
        self.content = content()
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).origin.y
                )
            }
            .frame(width: 0, height: 0)

            content
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            offsetChanged(offset)
        }
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

/// Updated CoreSearchBar component
fileprivate struct CoreSearchBar: View {
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
