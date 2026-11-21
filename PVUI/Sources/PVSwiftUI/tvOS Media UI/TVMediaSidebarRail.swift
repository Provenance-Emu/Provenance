import SwiftUI
import PVLibrary
import PVThemes
import PVUIBase
import Defaults
import PVSettings

#if os(tvOS) || os(iOS)

/// Premium Netflix-style sidebar with divine RetroWave aesthetics
/// Icon-only rail that expands elegantly on focus
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSidebarRail: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var destination: TVMediaDestination
    @ObservedObject var focusCoordinator: TVMediaFocusCoordinator
    @ObservedObject var router: TVMediaRouter

    let onSelectSettings: () -> Void
    let onSelectStatus: () -> Void
    let onSelectImports: () -> Void
    /// Opens Nearby Libraries (add, pair, manage); nil hides the Libraries section.
    var onSelectNearby: (() -> Void)?
    /// Libraries found on the network and saved servers, listed under Libraries.
    var libraries: [TVMediaSidebarLibrary] = []
    /// The library shown in the content area, or empty.
    var selectedLibraryID: String = ""
    var onSelectLibrary: ((String) -> Void)?

    let onSelectNetplay: () -> Void
    let onSelectHelp: () -> Void

    @Default(.netplayEnabled) private var netplayEnabled
    @AppStorage("TVMediaUI.sidebar.librariesExpanded") private var librariesExpanded = true

    @FocusState private var focusedItem: SidebarItem?
    @ObservedObject private var iconManager = IconManager.shared
    @Namespace private var sidebarAnimation
    @State private var appIcon: UIImage?
    #if os(iOS)
    /// The item the controller cursor is on. Plain state: SwiftUI focus does not hold a
    /// value on iOS unless a focusable view is bound to it.
    @State private var cursorItem: SidebarItem?
    #endif

    /// The highlighted item: the focus engine's on tvOS, the controller cursor's on iOS.
    private var activeItem: SidebarItem? {
        #if os(iOS)
        return focusCoordinator.isSidebarExpanded ? cursorItem : nil
        #else
        return focusedItem
        #endif
    }

    private let collapsedWidth: CGFloat = {
        #if os(iOS)
        return 72
        #else
        return 88
        #endif
    }()
    private let expandedWidth: CGFloat = {
        #if os(iOS)
        return 240
        #else
        return 300
        #endif
    }()

    private var iconFontSize: CGFloat {
        #if os(iOS)
        return 19
        #else
        return 22
        #endif
    }

    private var currentWidth: CGFloat {
        focusCoordinator.isSidebarExpanded ? expandedWidth : collapsedWidth
    }

    var body: some View {
        sidebarContent
            .frame(width: currentWidth)
            .frame(maxHeight: .infinity)
            .background(sidebarBackground)
            .tvMediaFocusSection()
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: focusCoordinator.isSidebarExpanded)
            #if os(tvOS)
            .onChange(of: focusedItem) { newItem in
                if newItem != nil {
                    focusCoordinator.sidebarGainedFocus()
                } else if focusCoordinator.activeZone == .sidebar {
                    focusCoordinator.sidebarLostFocus()
                }
            }
            .onChange(of: focusCoordinator.activeZone) { zone in
                if zone == .sidebar {
                    if focusedItem == nil {
                        focusedItem = itemForDestination(destination)
                    }
                } else {
                    focusedItem = nil
                }
            }
            #endif
            .onChange(of: focusCoordinator.isSidebarExpanded) { expanded in
                guard expanded else { return }
                #if os(iOS)
                cursorItem = itemForDestination(destination)
                #else
                focusedItem = itemForDestination(destination)
                #endif
            }
            .tvMediaOnMoveCommand { direction in
                if direction == .right && focusCoordinator.isSidebarExpanded {
                    focusedItem = nil
                    focusCoordinator.closeSidebar()
                }
            }
            .onAppear {
                loadAppIcon()
            }
            #if os(iOS)
            // B, Start and Options belong to the shell (`TVMediaMainRootView`), which
            // closes the sidebar. Handling them here too undid its work in the same press.
            .tvMediaControllerInput([.sidebar], coordinator: focusCoordinator) { event in
                switch event {
                case .verticalNavigation(let value, true):
                    moveSidebarCursor(isNext: value < 0)
                case .horizontalNavigation(let value, true) where value > 0:
                    focusCoordinator.closeSidebar()
                case .buttonPress(true):
                    activateSidebarCursor()
                default:
                    break
                }
            }
            #endif
    }

    private func itemForDestination(_ dest: TVMediaDestination) -> SidebarItem {
        switch dest {
        case .settings: return .settings
        case .status: return .status
        // A system's games are shown under the Systems item; there is no item of their own.
        case .systemGames: return .destination(.system)
        case .nearbyLibrary:
            let item = SidebarItem.library(selectedLibraryID)
            return libraryItems.contains(item) ? item : .nearby
        default: return .destination(dest)
        }
    }

    // MARK: - Content

    private var sidebarContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                logoSection
                    .padding(.bottom, 24)

                // All navigation items in a single VStack for proper focus flow
                ForEach(SidebarItem.mainNavItems, id: \.self) { item in
                    sidebarButton(for: item)
                        .id(item)
                }

                // Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.retroPink.opacity(0.25),
                                Color.retroBlue.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)

                // Footer items
                sidebarButton(for: .imports)
                    .id(SidebarItem.imports)
                if onSelectNearby != nil {
                    sidebarButton(for: .nearby)
                        .id(SidebarItem.nearby)
                    ForEach(libraryItems, id: \.self) { item in
                        sidebarButton(for: item)
                            .id(item)
                    }
                }
                if netplayEnabled {
                    sidebarButton(for: .netplay)
                        .id(SidebarItem.netplay)
                }
                sidebarButton(for: .settings)
                    .id(SidebarItem.settings)
                sidebarButton(for: .help)
                    .id(SidebarItem.help)
                sidebarButton(for: .destination(.logs))
                    .id(SidebarItem.destination(.logs))
                sidebarButton(for: .status)
                    .id(SidebarItem.status)
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
            .onChange(of: destination) { _ in
                let target = itemForDestination(destination)
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
            .onChange(of: activeItem) { newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        HStack(spacing: 14) {
            // App icon with neon halo
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.retroPink.opacity(focusCoordinator.isSidebarExpanded ? 0.25 : 0.15),
                                Color.retroBlue.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 36
                        )
                    )
                    .frame(width: 72, height: 72)

                // Icon container
                appIconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 12)
                    .shadow(color: Color.retroBlue.opacity(0.3), radius: 8)
            }

            if focusCoordinator.isSidebarExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROVENANCE")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(themeManager.currentPalette.menuText), Color.retroBlue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.retroPink.opacity(0.5), radius: 8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("EMULATOR")
                        .font(.system(size: 9, weight: .medium, design: .default))
                        .tracking(3)
                        .foregroundStyle(Color.retroPink.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: expandedWidth - 100, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)).animation(.easeOut(duration: 0.25).delay(0.1)),
                    removal: .opacity.animation(.easeIn(duration: 0.15))
                ))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .padding(.horizontal, 6)
    }

    private var appIconImage: Image {
        if let icon = appIcon {
            return Image(uiImage: icon)
        }
        return Image(systemName: "gamecontroller.fill")
    }

    /// Load the app icon using same logic as BootupViewRetroWave
    private func loadAppIcon() {
        let iconName = iconManager.currentIconName ?? "AppIcon"
        let previewImageName = "\(iconName)-Preview"

        // Check if using default or custom icon
        if iconName == "AppIcon" || iconName.isEmpty || iconName.lowercased() == "default" {
            // Load default from Info.plist
            if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let iconFileName = iconFiles.last,
               let icon = UIImage(named: iconFileName) {
                appIcon = icon
                return
            }

            // Fallback to AppIcon-Blue-Preview
            if let fallback = UIImage(named: "AppIcon-Blue-Preview", in: .main, with: nil) {
                appIcon = fallback
                return
            }
        } else {
            // Use preview image for alternate icons
            if let preview = UIImage(named: previewImageName, in: .main, with: nil) {
                appIcon = preview
                return
            }
        }

        // Final fallback
        appIcon = UIImage(named: "AppIcon-Blue-Preview", in: .main, with: nil)
    }

    // MARK: - Sidebar Button

    @ViewBuilder
    private func sidebarButton(for item: SidebarItem) -> some View {
        let isSelected = isSelected(item)
        let isFocused = activeItem == item
        let isLibraryRow = item.isLibraryRow

        Button {
            handleSelection(item)
        } label: {
            HStack(spacing: 16) {
                // Icon with dynamic styling
                ZStack {
                    // Focus glow behind icon
                    if isFocused {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.retroPink.opacity(0.4), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)
                            .blur(radius: 4)
                    }

                    Image(systemName: systemImage(for: item))
                        .font(.system(size: isLibraryRow ? iconFontSize - 4 : iconFontSize, weight: isFocused ? .medium : .light))
                        .foregroundStyle(
                            isFocused ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [Color(themeManager.currentPalette.menuText), Color.retroBlue.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )) :
                                AnyShapeStyle(isSelected ? Color(themeManager.currentPalette.menuText) : Color(themeManager.currentPalette.menuText).opacity(0.5))
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: isFocused ? Color.retroPink.opacity(0.8) : .clear, radius: 8)
                }
                .frame(width: 32)
                // The icon rail has no room for a list: the count says how many libraries are there.
                .overlay(alignment: .topTrailing) {
                    if item == .nearby, !focusCoordinator.isSidebarExpanded, !libraries.isEmpty {
                        libraryCountBadge.offset(x: 10, y: -8)
                    }
                }

                if focusCoordinator.isSidebarExpanded {
                    // A library's name is its owner's: shown as written, not in capitals.
                    Text(isLibraryRow ? title(for: item) : title(for: item).uppercased())
                        .font(.system(size: isLibraryRow ? 13 : 14, weight: isFocused ? .semibold : .medium, design: .default))
                        .tracking(isLibraryRow ? 0.3 : 1.5)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(
                            isFocused ? Color(themeManager.currentPalette.menuText) :
                            (isSelected ? Color(themeManager.currentPalette.menuText).opacity(0.9) : Color(themeManager.currentPalette.menuText).opacity(0.6))
                        )
                        .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 6)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)).animation(.easeOut(duration: 0.2).delay(0.05)),
                            removal: .opacity.animation(.easeIn(duration: 0.12))
                        ))

                    Spacer(minLength: 0)

                    if item == .nearby {
                        if !librariesExpanded, !libraries.isEmpty { libraryCountBadge }
                        Image(systemName: librariesExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.retroBlue.opacity(isFocused ? 0.9 : 0.5))
                    } else if isFocused {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.retroBlue.opacity(0.7))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            .frame(height: isLibraryRow ? 48 : 58)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, isLibraryRow ? 30 : 16)
            .padding(.trailing, 16)
            .background(buttonBackground(isFocused: isFocused, isSelected: isSelected))
            .overlay(buttonBorder(isFocused: isFocused))
            .shadow(color: isFocused ? Color.retroPink.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(TVMediaSidebarButtonStyle())
        .tvMediaFocusable()
        .focused($focusedItem, equals: item)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
    }

    private var libraryCountBadge: some View {
        Text("\(libraries.count)")
            .font(.system(size: 11, weight: .bold).monospacedDigit())
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(Color.retroBlue))
            .accessibilityLabel("\(libraries.count) \(libraries.count == 1 ? "library" : "libraries") found")
    }

    /// Rows under Libraries: one per library, then Add. Shown only while the sidebar and
    /// the section are both open.
    private var libraryItems: [SidebarItem] {
        guard onSelectNearby != nil, librariesExpanded, focusCoordinator.isSidebarExpanded else { return [] }
        return libraries.map { .library($0.id) } + [.addLibrary]
    }

    private func title(for item: SidebarItem) -> String {
        guard case .library(let id) = item else { return item.title }
        return libraries.first { $0.id == id }?.name ?? "Library"
    }

    private func systemImage(for item: SidebarItem) -> String {
        guard case .library(let id) = item else { return item.systemImage }
        return libraries.first { $0.id == id }?.systemImage ?? "books.vertical"
    }

    private func isSelected(_ item: SidebarItem) -> Bool {
        switch item {
        case .library(let id): return destination == .nearbyLibrary && id == selectedLibraryID
        // With its rows hidden, the header stands for the library that is open.
        case .nearby: return destination == .nearbyLibrary && libraryItems.isEmpty
        default: return item.matchesDestination(destination)
        }
    }

    private func buttonBackground(isFocused: Bool, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                isFocused ?
                    LinearGradient(
                        colors: [
                            Color.retroPink.opacity(0.18),
                            Color.retroBlue.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    (isSelected ?
                        LinearGradient(
                            colors: [Color(themeManager.currentPalette.menuText).opacity(0.06), Color(themeManager.currentPalette.menuText).opacity(0.03)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing))
            )
    }

    private func buttonBorder(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isFocused ?
                    LinearGradient(
                        colors: [
                            Color.retroPink.opacity(0.8),
                            Color.retroBlue.opacity(0.6),
                            Color.retroPink.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing),
                lineWidth: isFocused ? 2 : 0
            )
    }

    private func handleSelection(_ item: SidebarItem) {
        switch item {
        case .destination(let dest):
            destination = dest
            router.navigate(to: dest)
        case .settings:
            destination = .settings
            onSelectSettings()
        case .status:
            destination = .status
            onSelectStatus()
        case .imports:
            onSelectImports()
        case .nearby:
            // Opens and closes the list; the sidebar stays open with the cursor on the header.
            withAnimation(.easeInOut(duration: 0.2)) { librariesExpanded.toggle() }
            return
        case .library(let id):
            onSelectLibrary?(id)
        case .addLibrary:
            onSelectNearby?()
        case .netplay:
            onSelectNetplay()
        case .help:
            onSelectHelp()
        }

        focusedItem = nil
        focusCoordinator.closeSidebar()
    }

    // MARK: - Background

    private var sidebarBackground: some View {
        ZStack {
            // Palette surface
            Rectangle()
                .fill(Color(themeManager.currentPalette.menuBackground))

            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.retroPink.opacity(0.02),
                    Color.clear,
                    Color.retroBlue.opacity(0.015)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Right edge glow line
            HStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.retroPink.opacity(focusCoordinator.isSidebarExpanded ? 0.25 : 0.12),
                                Color.retroBlue.opacity(focusCoordinator.isSidebarExpanded ? 0.2 : 0.08),
                                Color.retroPink.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 8, x: -4, y: 0)
            }

            // Scanline texture overlay for CRT feel
            scanlineOverlay
                .opacity(0.03)
        }
        .shadow(color: Color.retroPink.opacity(0.1), radius: 30, x: 8, y: 0)
        .shadow(color: .black.opacity(themeManager.currentPalette.dark ? 0.45 : 0.08), radius: 24, x: 6, y: 0)
    }

    private var scanlineOverlay: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<Int(geo.size.height / 3), id: \.self) { _ in
                    Color.clear.frame(height: 2)
                    Color(themeManager.currentPalette.menuText).frame(height: 1)
                }
            }
        }
    }

    private var sidebarItems: [SidebarItem] {
        var items = SidebarItem.mainNavItems
        items.append(.imports)
        if onSelectNearby != nil {
            items.append(.nearby)
            items += libraryItems
        }
        if netplayEnabled {
            items.append(.netplay)
        }
        items += [.settings, .help, .destination(.logs), .status]
        return items
    }

    #if os(iOS)
    private func moveSidebarCursor(isNext: Bool) {
        let items = sidebarItems
        guard !items.isEmpty else { return }
        let current = cursorItem ?? itemForDestination(destination)
        guard let index = items.firstIndex(of: current) else {
            cursorItem = items.first
            return
        }
        let nextIndex = isNext ? min(index + 1, items.count - 1) : max(index - 1, 0)
        cursorItem = items[nextIndex]
    }

    private func activateSidebarCursor() {
        handleSelection(cursorItem ?? itemForDestination(destination))
    }
    #endif
}

/// One library listed in the sidebar: a device found on the network or a saved server.
struct TVMediaSidebarLibrary: Identifiable, Hashable {
    /// The peer's id; `NearbyLibrariesModel.peerModel(forPeerID:)` takes it.
    let id: String
    let name: String
    let systemImage: String
}

// MARK: - Sidebar Item Enum

@available(tvOS 16.0, iOS 17.0, *)
private enum SidebarItem: Hashable {
    case destination(TVMediaDestination)
    case settings
    case status
    case imports
    /// The Libraries header: opens and closes the list under it.
    case nearby
    /// One library on the network or a saved server, by peer id.
    case library(String)
    /// Opens Nearby Libraries to add a server, pair, or manage.
    case addLibrary
    case netplay
    case help

    var isLibraryRow: Bool {
        switch self {
        case .library, .addLibrary: return true
        default: return false
        }
    }

    static let mainNavItems: [SidebarItem] = [
        .destination(.home),
        .destination(.system),
        .destination(.search),
        .destination(.favorites),
        .destination(.saves),
        //.imports
    ]

    var title: String {
        switch self {
        case .destination(let dest): return dest.title
        case .settings: return "Settings"
        case .status: return "Status"
        case .imports: return "Imports"
        case .nearby: return "Libraries"
        case .library: return "Library"
        case .addLibrary: return "Add or Manage…"
        case .netplay: return "Network Play"
        case .help: return "Help"
        }
    }

    var systemImage: String {
        switch self {
        case .destination(let dest):
            switch dest {
            case .home: return "house"
            case .system, .systemGames: return "square.stack.3d.up"
            case .search: return "magnifyingglass"
            case .favorites: return "heart"
            case .saves: return "bookmark"
            case .logs: return "doc.text"
            case .settings: return "gearshape"
            case .status: return "info.circle"
            case .nearbyLibrary: return "antenna.radiowaves.left.and.right"
            }
        case .settings: return "gearshape"
        case .status: return "info.circle"
        case .imports: return "tray.and.arrow.down"
        case .nearby: return "antenna.radiowaves.left.and.right"
        case .library: return "books.vertical"
        case .addLibrary: return "plus.circle"
        case .netplay: return "network"
        case .help: return "questionmark.circle"
        }
    }

    func matchesDestination(_ dest: TVMediaDestination) -> Bool {
        switch self {
        case .destination(let d):
            if d == .system && dest == .systemGames { return true }
            return d == dest
        case .settings: return dest == .settings
        case .status: return dest == .status
        case .imports, .nearby, .library, .addLibrary, .netplay, .help: return false
        }
    }
}

// MARK: - Button Style

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#endif
