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
    /// Track scroll offset to hide/show the reset button
    @State private var scrollOffset: CGFloat = 0
    /// Previous scroll offset to determine direction
    @State private var previousScrollOffset: CGFloat = 0
    /// Whether the button is visible
    @State private var isButtonVisible = true
    /// Threshold for hiding/showing the button
    private let scrollThreshold: CGFloat = 20

    /// The body of the view
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollViewWithOffset(
                axes: .vertical,
                showsIndicators: true,
                offsetChanged: { offset in
                    handleScrollOffset(offset)
                }
            ) {
                LazyVStack {
                    // Spacer to account for the floating button
                    Color.clear.frame(height: 70)

                    ForEach(coreItems) { item in
                        NavigationLink {
                            CoreOptionsDetailView(coreClass: item.coreClass, title: item.name)
                        } label: {
                            CoreListItemView(item: item)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom)
            }

            // Floating reset button
            resetButton
                .zIndex(1) // Ensure button stays on top
        }
        .searchable(text: $searchText)
        .navigationTitle("Core Options")
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

    /// Handle scroll offset changes to show/hide the button
    private func handleScrollOffset(_ offset: CGFloat) {
        // Only show button when at or near the top of the content
        let isAtTop = offset >= -10 // Allow a small threshold for "top" position

        // If we're at the top, always show the button
        if isAtTop && !isButtonVisible {
            withAnimation(.spring(response: 0.3)) {
                isButtonVisible = true
            }
        }
        // If we're scrolling down and button is visible, hide it
        else if !isAtTop && isButtonVisible && offset < previousScrollOffset {
            withAnimation(.spring(response: 0.3)) {
                isButtonVisible = false
            }
        }

        // Update previous offset for next comparison
        previousScrollOffset = offset
    }

    /// The reset button view
    private var resetButton: some View {
        Button(action: {
            showResetAllConfirmation = true
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset All Core Options")
            }
            .padding()
            .frame(maxWidth: .infinity)
            #if os(tvOS)
            // Use tvOS-specific styling
            .background(Color.red.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(5)
            .padding(.horizontal, 40)
            .focusable(true)
            .buttonStyle(.card)
            #else
            // Use iOS-specific styling
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            #endif
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
        // Use both scale and opacity for a more dramatic effect
        .opacity(isButtonVisible ? 1 : 0)
        .scaleEffect(isButtonVisible ? 1 : 0.5, anchor: .top)
        // Add a slight vertical offset when hiding
        .offset(y: isButtonVisible ? 0 : -20)
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

/// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
