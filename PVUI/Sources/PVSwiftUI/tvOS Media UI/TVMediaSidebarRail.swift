import SwiftUI
import PVLibrary
import PVThemes
import PVUIBase

#if os(tvOS) || os(iOS)

/// Premium Netflix-style sidebar with divine RetroWave aesthetics
/// Icon-only rail that expands elegantly on focus
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSidebarRail: View {
    @Binding var destination: TVMediaDestination
    @ObservedObject var focusCoordinator: TVMediaFocusCoordinator
    @ObservedObject var router: TVMediaRouter

    let onSelectSettings: () -> Void
    let onSelectStatus: () -> Void
    let onSelectImports: () -> Void

    @FocusState private var focusedItem: SidebarItem?
    @ObservedObject private var iconManager = IconManager.shared
    @Namespace private var sidebarAnimation
    @State private var appIcon: UIImage?
    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

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
            .onChange(of: focusCoordinator.isSidebarExpanded) { expanded in
                if expanded {
                    focusedItem = itemForDestination(destination)
                }
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
            .onReceive(gamepadManager.eventPublisher) { event in
                guard gamepadManager.isControllerConnected else { return }
                switch event {
                case .menuToggle(let isPressed):
                    if isPressed {
                        focusCoordinator.toggleSidebar()
                    }
                case .verticalNavigation(let value, let isPressed):
                    guard isPressed else { return }
                    moveSidebarFocus(isNext: value < 0)
                case .buttonPress(let isPressed):
                    guard isPressed else { return }
                    activateFocusedSidebar()
                case .buttonB(let isPressed):
                    guard isPressed else { return }
                    if focusCoordinator.isSidebarExpanded {
                        focusCoordinator.closeSidebar()
                    }
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
                sidebarButton(for: .settings)
                    .id(SidebarItem.settings)
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
            .onChange(of: focusedItem) { newValue in
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
                                colors: [.white, Color.retroBlue.opacity(0.8)],
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
        let isSelected = item.matchesDestination(destination)
        let isFocused = focusedItem == item

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

                    Image(systemName: item.systemImage)
                        .font(.system(size: iconFontSize, weight: isFocused ? .medium : .light))
                        .foregroundStyle(
                            isFocused ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [.white, Color.retroBlue.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )) :
                                AnyShapeStyle(isSelected ? Color.white : Color.white.opacity(0.5))
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: isFocused ? Color.retroPink.opacity(0.8) : .clear, radius: 8)
                }
                .frame(width: 32)

                if focusCoordinator.isSidebarExpanded {
                    Text(item.title.uppercased())
                        .font(.system(size: 14, weight: isFocused ? .semibold : .medium, design: .default))
                        .tracking(1.5) // Refined letter spacing
                        .foregroundStyle(
                            isFocused ? .white :
                            (isSelected ? .white.opacity(0.9) : .white.opacity(0.6))
                        )
                        .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 6)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)).animation(.easeOut(duration: 0.2).delay(0.05)),
                            removal: .opacity.animation(.easeIn(duration: 0.12))
                        ))

                    Spacer(minLength: 0)

                    // Subtle chevron indicator for focused item
                    if isFocused {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.retroBlue.opacity(0.7))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            .frame(height: 58)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
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
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
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
        }

        focusedItem = nil
        focusCoordinator.closeSidebar()
    }

    // MARK: - Background

    private var sidebarBackground: some View {
        ZStack {
            // Deep dark base
            Rectangle()
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))

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
        .shadow(color: .black.opacity(0.9), radius: 50, x: 15, y: 0)
    }

    private var scanlineOverlay: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<Int(geo.size.height / 3), id: \.self) { _ in
                    Color.clear.frame(height: 2)
                    Color.white.frame(height: 1)
                }
            }
        }
    }

    private var sidebarItems: [SidebarItem] {
        SidebarItem.mainNavItems + [
            .imports,
            .settings,
            .destination(.logs),
            .status
        ]
    }

    private func moveSidebarFocus(isNext: Bool) {
        let items = sidebarItems
        guard !items.isEmpty else { return }
        let current = focusedItem ?? itemForDestination(destination)
        guard let index = items.firstIndex(of: current) else {
            focusedItem = items.first
            return
        }
        let nextIndex = isNext ? min(index + 1, items.count - 1) : max(index - 1, 0)
        focusedItem = items[nextIndex]
    }

    private func activateFocusedSidebar() {
        guard let focusedItem else { return }
        handleSelection(focusedItem)
    }
}

// MARK: - Sidebar Item Enum

@available(tvOS 16.0, iOS 17.0, *)
private enum SidebarItem: Hashable {
    case destination(TVMediaDestination)
    case settings
    case status
    case imports

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
            }
        case .settings: return "gearshape"
        case .status: return "info.circle"
        case .imports: return "tray.and.arrow.down"
        }
    }

    func matchesDestination(_ dest: TVMediaDestination) -> Bool {
        switch self {
        case .destination(let d):
            if d == .system && dest == .systemGames { return true }
            return d == dest
        case .settings: return dest == .settings
        case .status: return dest == .status
        case .imports: return false
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
