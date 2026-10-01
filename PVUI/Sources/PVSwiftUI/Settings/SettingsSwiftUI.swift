import SwiftUI
import PVLibrary
import PVSupport
import PVLogging
import Reachability
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import Combine
import PVUIBase
import PVUIKit
import RxRealm
import RxSwift
import RealmSwift
import PVFeatureFlags
import Defaults
import AudioToolbox
import PVCheevos

#if canImport(GameController)
import GameController
#endif

#if canImport(FreemiumKit)
import FreemiumKit
#endif
#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(PVWebServer)
import PVWebServer
#endif

// MARK: - tvOS Navigation Support

/// ViewModifier that adds proper navigation support for tvOS
@available(tvOS 13.0, *)
struct TVOSNavigationSupport: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss
#if os(tvOS)
    @Environment(\.retroTabNavigationState) private var navigationState
#endif

    func body(content: Content) -> some View {
        content
        #if os(tvOS)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.retroBlue)
                }
            }
            .onExitCommand {
                navigationState?.suppressTabBarFocus = true
                dismiss()
            }
        #endif
    }
}

#if os(tvOS)
/// Increments/decrements a shared refcount so nested settings destinations (A → B) keep
/// `depth > 0` until the last tracked view disappears; a plain `Bool` would clear on the first pop.
private enum SettingsSubpageDepthTracking {
    /// Registers one pushed settings subpage; no-op when `depth` is `nil` (e.g. inside a detached sheet).
    static func register(_ depth: Binding<Int>?) {
        guard let depth else { return }
        depth.wrappedValue += 1
    }

    /// Unregisters one subpage; clamps at zero.
    static func unregister(_ depth: Binding<Int>?) {
        guard let depth else { return }
        depth.wrappedValue = max(0, depth.wrappedValue - 1)
    }
}

/// Environment key: refcount of tracked NavigationLink destinations under Settings’ root stack.
/// `nil` means “do not mutate” (sheet / overlay trees use this to avoid corrupting the root count).
private struct SettingsSubpageDepthKey: EnvironmentKey {
    static let defaultValue: Binding<Int>? = nil
}

extension EnvironmentValues {
    /// Refcount binding from `PVSettingsView`; child destinations increment on appear and decrement on disappear.
    var settingsSubpageDepth: Binding<Int>? {
        get { self[SettingsSubpageDepthKey.self] }
        set { self[SettingsSubpageDepthKey.self] = newValue }
    }
}

extension View {
    /// Detaches presented content from the settings subpage refcount so sheet dismissals do not desync the main stack.
    func settingsSheetDetachedFromSubpageDepth() -> some View {
        environment(\.settingsSubpageDepth, nil)
    }
}

/// ViewModifier that contains focus within a subpage to prevent accidental back navigation
/// when scrolling past content on tvOS. This prevents focus from escaping to parent tab bars.
@available(tvOS 14.0, *)
struct TVOSSubpageFocusContainment: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsSubpageDepth) private var settingsSubpageDepth

    func body(content: Content) -> some View {
        content
            .focusSection()
            .onExitCommand {
                dismiss()
            }
            .onAppear { SettingsSubpageDepthTracking.register(settingsSubpageDepth) }
            .onDisappear { SettingsSubpageDepthTracking.unregister(settingsSubpageDepth) }
    }
}

// MARK: - Settings Subpage Tracking

/// ViewModifier applied to NavigationLink destinations that adjusts the settings subpage refcount on appear/disappear.
struct SettingsSubpageTracker: ViewModifier {
    @Environment(\.settingsSubpageDepth) private var settingsSubpageDepth

    func body(content: Content) -> some View {
        content
            .onAppear { SettingsSubpageDepthTracking.register(settingsSubpageDepth) }
            .onDisappear { SettingsSubpageDepthTracking.unregister(settingsSubpageDepth) }
    }
}
#endif

extension View {
    /// Adds tvOS navigation support with a back button
    func tvOSNavigationSupport(title: String) -> some View {
        #if os(tvOS)
        self.modifier(TVOSNavigationSupport(title: title))
        #else
        self
        #endif
    }

    /// Adds focus containment for tvOS subpages to prevent accidental back navigation
    /// when scrolling past content. Focus will stay within the subpage.
    func tvOSSubpageFocusContainment() -> some View {
        #if os(tvOS)
        if #available(tvOS 14.0, *) {
            return AnyView(self.modifier(TVOSSubpageFocusContainment()))
        } else {
            return AnyView(self)
        }
        #else
        return self
        #endif
    }

    /// Marks this view as a settings subpage so the parent can track push state.
    func settingsSubpageTracking() -> some View {
        #if os(tvOS)
        self.modifier(SettingsSubpageTracker())
        #else
        self
        #endif
    }
}

#if os(tvOS)
/// A wrapper view for NavigationLink destinations on tvOS that properly contains focus
/// and prevents accidental back navigation when scrolling past content.
@available(tvOS 14.0, *)
struct TVOSSettingsSubpage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsSubpageDepth) private var settingsSubpageDepth

    var body: some View {
        ScrollView {
            content()
                .padding(.bottom, 50)
        }
        .focusSection()
        .navigationTitle(title)
        .onExitCommand {
            dismiss()
        }
        .onAppear { SettingsSubpageDepthTracking.register(settingsSubpageDepth) }
        .onDisappear { SettingsSubpageDepthTracking.unregister(settingsSubpageDepth) }
    }
}

/// Helper to wrap navigation destinations for tvOS with proper focus containment
extension View {
    /// Wraps the view in a tvOS-optimized subpage container that prevents focus escape
    @ViewBuilder
    func tvOSSettingsDestination(title: String) -> some View {
        #if os(tvOS)
        if #available(tvOS 14.0, *) {
            TVOSSettingsSubpage(title: title) {
                self
            }
        } else {
            self.navigationTitle(title)
        }
        #else
        self
        #endif
    }
}
#endif

// MARK: - tvOS Premium Settings Components

#if os(tvOS)
/// Cinematic background for tvOS settings matching the Media UI aesthetic
struct TVOSSettingsBackground: View {
    var body: some View {
        ZStack {
            // Deep space gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.06),
                    Color(red: 0.05, green: 0.03, blue: 0.10),
                    Color(red: 0.03, green: 0.02, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle horizon glow
            RadialGradient(
                colors: [
                    Color.retroPink.opacity(0.08),
                    Color.retroBlue.opacity(0.04),
                    .clear
                ],
                center: .bottom,
                startRadius: 100,
                endRadius: 800
            )

            // Grid pattern overlay
            TVOSSettingsGridPattern()
                .opacity(0.03)

            // Subtle scanlines
            TVOSSettingsScanlines()
                .opacity(0.015)
        }
    }
}

/// Grid pattern for settings background
struct TVOSSettingsGridPattern: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let spacing: CGFloat = 60
                let lineWidth: CGFloat = 0.5

                // Vertical lines
                for x in stride(from: 0, through: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: lineWidth)
                }

                // Horizontal lines
                for y in stride(from: 0, through: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: lineWidth)
                }
            }
        }
    }
}

/// Subtle CRT scanlines
struct TVOSSettingsScanlines: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let lineSpacing: CGFloat = 3

                for y in stride(from: 0, through: size.height, by: lineSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.black.opacity(0.4)), lineWidth: 1)
                }
            }
        }
    }
}

/// Premium header for tvOS settings
struct TVOSSettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                // Neon accent bar
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.retroPink.opacity(0.5))
                        .frame(width: 6, height: 50)
                        .blur(radius: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.retroPink, Color.retroBlue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 48)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.title", bundle: .module)
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.retroBlue.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.retroPink.opacity(0.5), radius: 15, x: 0, y: 0)

                    Text("settings.subtitle", bundle: .module)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .tracking(3)
                        .foregroundStyle(Color.retroPink.opacity(0.7))
                }

                Spacer()

                // Provenance logo
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.6), Color.retroBlue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 10)
            }

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.retroPink.opacity(0.8),
                            Color.retroBlue.opacity(0.6),
                            Color.retroPink.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: Color.retroPink.opacity(0.5), radius: 4)
        }
        .focusable(false)
    }
}

/// Persistence of tvOS section expansion. Separate keys per section (not `Defaults[.collapsedSections]`) so the
/// iOS collapse state is unaffected: tvOS starts collapsed, iOS starts expanded.
enum TVOSSettingsSectionState {
    static func storageKey(for title: String) -> String {
        "tvOSSettingsSectionExpanded.\(title)"
    }
}

/// Section title the settings root wants focused after a search selection; sections compare it to their own title.
private struct TVOSSettingsFocusTargetKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var tvOSSettingsFocusTarget: String? {
        get { self[TVOSSettingsFocusTargetKey.self] }
        set { self[TVOSSettingsFocusTargetKey.self] = newValue }
    }
}

/// Premium collapsible section for tvOS settings.
///
/// Collapsed sections do not build their rows, which keeps the long single-page layout cheap to scroll with a remote.
struct TVOSSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool
    @FocusState private var headerFocused: Bool
    @Environment(\.tvOSSettingsFocusTarget) private var focusTarget

    init(title: String, icon: String, defaultExpanded: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
        _isExpanded = AppStorage(wrappedValue: defaultExpanded, TVOSSettingsSectionState.storageKey(for: title))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    // Icon with glow
                    ZStack {
                        if headerFocused {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.retroPink.opacity(0.4), .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 30
                                    )
                                )
                                .frame(width: 60, height: 60)
                        }

                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                headerFocused ?
                                    AnyShapeStyle(LinearGradient(
                                        colors: [.white, Color.retroBlue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )) :
                                    AnyShapeStyle(Color.white.opacity(0.6))
                            )
                            .shadow(color: headerFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 8)
                    }
                    .frame(width: 44, height: 44)

                    Text(title.uppercased())
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .tracking(1.5)
                        .foregroundStyle(
                            headerFocused ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [.white, Color.retroBlue.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )) :
                                AnyShapeStyle(Color.white.opacity(0.85))
                        )

                    Spacer()

                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            headerFocused ?
                                AnyShapeStyle(Color.retroPink) :
                                AnyShapeStyle(Color.white.opacity(0.4))
                        )
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            headerFocused ?
                                LinearGradient(
                                    colors: [Color.retroPink.opacity(0.15), Color.retroBlue.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.04), Color.white.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            headerFocused ?
                                LinearGradient(
                                    colors: [Color.retroPink.opacity(0.8), Color.retroBlue.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                            lineWidth: headerFocused ? 2 : 1
                        )
                )
                .shadow(color: headerFocused ? Color.retroPink.opacity(0.3) : .clear, radius: 15, x: 0, y: 5)
            }
            .buttonStyle(TVOSSettingsSectionButtonStyle())
            .focused($headerFocused)
            .scaleEffect(headerFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: headerFocused)

            // Section content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        // Scroll target for the settings root (search results scroll to a section by title).
        .id(title)
        .onChange(of: focusTarget) { _, target in
            guard target == title else { return }
            isExpanded = true
            headerFocused = true
        }
    }
}

/// Button style that removes default tvOS highlight
struct TVOSSettingsSectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}
#endif

// MARK: - PVSettingsView
public struct PVSettingsView: View {

    @StateObject private var viewModel: PVSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    private let settingsNavigator = SettingsNavigator.shared
    var dismissAction: () -> Void
    weak var menuDelegate: PVMenuDelegate!

    @ObservedObject var conflictsController: PVGameLibraryUpdatesController

    @State public var showsDoneButton: Bool = true
    #if !os(tvOS)
    @State private var selectedTab: Int = 0
    @State private var searchQuery = ""
    @FocusState private var searchFocused: Bool
    /// Section chosen from search; consumed by the destination tab once it is on screen.
    @State private var pendingScrollSection: String?
    #endif
    @State private var showCloudSync = false
    @State private var showWiki = false
    @State private var destinationCancellable: AnyCancellable?

    #if os(tvOS)
    /// Section chosen from search while the search page was open; revealed once the page has popped.
    @State private var pendingSearchSection: String?
    /// Section whose header should take focus (see `tvOSSettingsFocusTarget`).
    @State private var focusTargetSection: String?
    /// Refcount of tracked subpages (NavigationLink destinations using `.settingsSubpageTracking()` etc.).
    @State private var settingsSubpageDepth = 0
    /// Callback to notify the parent wrapper when subpage push state changes (`depth > 0`).
    var onSubpagePushChanged: ((Bool) -> Void)?
    #endif

    #if os(tvOS)
    public init(conflictsController: PVGameLibraryUpdatesController, menuDelegate: PVMenuDelegate, showsDoneButton: Bool = true, onSubpagePushChanged: ((Bool) -> Void)? = nil, dismissAction: @escaping () -> Void) {
        self.conflictsController = conflictsController
        self.dismissAction = dismissAction
        self.onSubpagePushChanged = onSubpagePushChanged
        _viewModel = StateObject(wrappedValue: PVSettingsViewModel(menuDelegate: menuDelegate, conflictsController: conflictsController))
        self.showsDoneButton = showsDoneButton
    }
    #else
    public init(conflictsController: PVGameLibraryUpdatesController, menuDelegate: PVMenuDelegate, showsDoneButton: Bool = true, dismissAction: @escaping () -> Void) {
        self.conflictsController = conflictsController
        self.dismissAction = dismissAction
        _viewModel = StateObject(wrappedValue: PVSettingsViewModel(menuDelegate: menuDelegate, conflictsController: conflictsController))
        self.showsDoneButton = showsDoneButton
    }
    #endif

    public var body: some View {
        NavigationStack {
            ZStack {
                #if !os(tvOS)
                navigationLinks
                #endif
                // Background using theme palette
                Color(themeManager.currentPalette.gameLibraryBackground)
                    .edgesIgnoringSafeArea(.all)

                // Grid background
                RetroGridForSettings()
                    .edgesIgnoringSafeArea(.all)
                    .opacity(themeManager.currentPalette.dark ? 0.5 : 0.2)

                #if !os(tvOS)
                // Tabbed interface for iOS
                RetroTabView(
                    selection: $selectedTab,
                    content: {
                        VStack(spacing: 0) {
                            SettingsSearchField(text: $searchQuery, isFocused: $searchFocused)
                                .padding(.horizontal)
                                // Clears the hand-drawn Done / Help buttons overlaid at the top.
                                .padding(.top, showsDoneButton ? Self.doneBarClearance : Self.searchFieldTopPadding)
                                .padding(.bottom, 4)

                            if isSearching {
                                SettingsSearchResultsView(query: searchQuery, onSelect: selectSearchResult)
                            } else {
                                Group {
                                    switch selectedTab {
                                    case 0:
                                        generalTabContent
                                    case 1:
                                        emulationTabContent
                                    case 2:
                                        controllerTabContent
                                    case 3:
                                        advancedTabContent
                                    case 4:
                                        aboutTabContent
                                    default:
                                        generalTabContent
                                    }
                                }
                            }
                        }
                    },
                    tabItems: tabItems
                )
                .overlay(
                    // Custom navigation bar overlay
                    VStack {
                        HStack {
                            if showsDoneButton {
                                Button(action: { dismissAction() }) {
                                    Text("settings.done", bundle: .module)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .strokeBorder(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            ),
                                                            lineWidth: 1.5
                                                        )
                                                )
                                        )
                                }

                                Spacer()

                                Button(action: { showWiki = true }) {
                                    Text("settings.help", bundle: .module)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .strokeBorder(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            ),
                                                            lineWidth: 1.5
                                                        )
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        Spacer()
                    }
                )
                #else
                // Premium tvOS Settings with RetroWave styling
                ZStack {
                    // Cinematic background matching tvOS Media UI
                    TVOSSettingsBackground()
                        .ignoresSafeArea()

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 28) {
                                // Premium header
                                TVOSSettingsHeader()
                                    .padding(.top, 40)
                                    .padding(.bottom, 20)

                                #if canImport(FreemiumKit)
                                PlusStatusBanner()
                                    .padding(.bottom, 8)
                                #endif

                                NavigationLink {
                                    TVOSSettingsSearchView(onSelect: selectSearchResult)
                                } label: {
                                    SettingsRow(title: "Search Settings",
                                                subtitle: "Find a setting by name.",
                                                icon: .sfSymbol("magnifyingglass"))
                                }
                                .retroFocusButtonStyle(showBorder: false)

                                // Settings sections with premium styling. Only the first starts expanded.
                                TVOSSettingsSection(title: SettingsSectionTitle.app, icon: "gearshape.fill", defaultExpanded: true) {
                                    AppSection(viewModel: viewModel)
                                        .environmentObject(viewModel)
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.coreOptions, icon: "cpu") {
                                    CoreOptionsSection()
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.saves, icon: "square.and.arrow.down.fill") {
                                    SavesSection()
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.audio, icon: "speaker.wave.3.fill") {
                                    AudioSection()
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.video, icon: "tv.fill") {
                                    VideoSection()
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.controller, icon: "gamecontroller.fill") {
                                    ControllerSection()
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.retroAchievements, icon: "trophy.fill") {
                                    RetroAchievementsSection(viewModel: viewModel)
                                        .environmentObject(viewModel)
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.library, icon: "books.vertical.fill") {
                                    LibrarySection(viewModel: viewModel)
                                        .environmentObject(viewModel)
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.libraryManagement, icon: "folder.badge.gearshape") {
                                    LibrarySection2(viewModel: viewModel)
                                        .environmentObject(viewModel)
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.advanced, icon: "wrench.and.screwdriver.fill") {
                                    AdvancedSection()
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.build, icon: "hammer.fill") {
                                    BuildSection(viewModel: viewModel)
                                        .environmentObject(viewModel)
                                }

                                TVOSSettingsSection(title: SettingsSectionTitle.tvOSAbout, icon: "info.circle.fill") {
                                    ExtraInfoSection()
                                }
                            }
                            .padding(.horizontal, 80)
                            .padding(.bottom, 80)
                        }
                        // NOTE: Do NOT apply TVOSSettingsSectionButtonStyle here — it would
                        // override NavigationLink buttons inside each section and prevent
                        // navigation from working on tvOS. Each section header applies the
                        // style to its own expand/collapse button individually (line ~430).
                        .focusSection()
                        .environment(\.tvOSSettingsFocusTarget, focusTargetSection)
                        .onAppear { revealPendingSearchSection(proxy) }
                        .onChange(of: settingsSubpageDepth) { _, depth in
                            if depth == 0 { revealPendingSearchSection(proxy) }
                        }
                    }
                }
                #endif
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #if os(tvOS)
        .environment(\.settingsSubpageDepth, $settingsSubpageDepth)
        .onChange(of: settingsSubpageDepth) { depth in
            onSubpagePushChanged?(depth > 0)
        }
        #endif
        .onAppear {
            #if !os(tvOS)
            subscribeSettingsDestination()
            handleSettingsDestination(settingsNavigator.destination)
            #endif
        }
        .onDisappear {
            destinationCancellable?.cancel()
            destinationCancellable = nil
        }
        .sheet(isPresented: $showWiki) {
            NavigationStack {
                WikiHelpView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showWiki = false }
                        }
                    }
            }
            #if os(tvOS)
            .settingsSheetDetachedFromSubpageDepth()
            #endif
        }
    }

    #if !os(tvOS)
    /// Top inset that keeps the search field below the Done / Help buttons overlaid on the tab content.
    private static let doneBarClearance: CGFloat = 52
    /// Top inset of the search field when there is no Done / Help row.
    private static let searchFieldTopPadding: CGFloat = 8

    private var isSearching: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= SettingsSearchIndex.minimumQueryLength
    }

    /// Jumps to the chosen setting's tab, opens its section and (once that tab is on screen) scrolls to it.
    private func selectSearchResult(_ entry: SettingsSearchEntry) {
        searchQuery = ""
        searchFocused = false
        CollapsibleSectionExpansion.expand(title: entry.section)
        pendingScrollSection = entry.section
        selectedTab = entry.tab.rawValue
    }

    /// Scroll container shared by the tabs. Tab content is rebuilt on every tab switch, so the scroll to a
    /// section picked from search happens here, after the new tab has appeared.
    private func tabScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let tabContent = content()
        return ScrollViewReader { proxy in
            ScrollView {
                tabContent
            }
            .task {
                guard let section = pendingScrollSection else { return }
                pendingScrollSection = nil
                await Task.yield()
                withAnimation {
                    proxy.scrollTo(section, anchor: .top)
                }
            }
        }
    }

    private var tabItems: [RetroTabItem] {
        [
            RetroTabItem(title: "General", systemImage: "gearshape.fill"),
            RetroTabItem(title: "Emulation", systemImage: "gamecontroller.fill"),
            RetroTabItem(title: "Controller", systemImage: "hand.raised.fill"),
            RetroTabItem(title: "Advanced", systemImage: "gearshape.2.fill"),
            RetroTabItem(title: "About", systemImage: "info.circle.fill")
        ]
    }

    @ViewBuilder
    private var navigationLinks: some View {
        NavigationLink(destination: CloudSyncSettingsView(), isActive: $showCloudSync) { EmptyView() }
            .hidden()
    }

    private func subscribeSettingsDestination() {
        guard destinationCancellable == nil else { return }
        destinationCancellable = settingsNavigator.$destination.sink { dest in
            handleSettingsDestination(dest)
        }
    }

    private func handleSettingsDestination(_ destination: SettingsDestination) {
        switch destination {
        case .cloudSync:
            showCloudSync = true
            settingsNavigator.navigate(to: .none)
        case .tab(let tab):
            selectedTab = tab.rawValue
            settingsNavigator.navigate(to: .none)
        case .none:
            break
        }
    }

    private var generalTabContent: some View {
        tabScrollView {
            VStack(spacing: 16) {
                Text("settings.tab.general", bundle: .module)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                #if canImport(FreemiumKit)
                PlusStatusBanner()
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                #endif

                VStack(spacing: 16) {
                    CollapsibleSection(title: SettingsSectionTitle.app) {
                        AppSection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                    CollapsibleSection(title: SettingsSectionTitle.library) {
                        LibrarySection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                    CollapsibleSection(title: SettingsSectionTitle.libraryManagement) {
                        LibrarySection2(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }

    private var emulationTabContent: some View {
        tabScrollView {
            VStack(spacing: 16) {
                Text("settings.tab.emulation", bundle: .module)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                VStack(spacing: 16) {
                    CollapsibleSection(title: SettingsSectionTitle.coreOptions) {
                        CoreOptionsSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.saves) {
                        SavesSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.audio) {
                        AudioSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.video) {
                        VideoSection()
                    }
#if os(iOS)
                    CollapsibleSection(title: SettingsSectionTitle.recording) {
                        RecordingSection()
                    }
#endif
                    CollapsibleSection(title: SettingsSectionTitle.retroAchievements) {
                        RetroAchievementsSection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }

    private var controllerTabContent: some View {
        tabScrollView {
            VStack(spacing: 16) {
                Text("settings.tab.controller", bundle: .module)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                VStack(spacing: 16) {
                    CollapsibleSection(title: SettingsSectionTitle.controller) {
                        ControllerRowsSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.hapticsRumble) {
                        HapticsRumbleSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.dualSense) {
                        DualSenseExtrasSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.onScreenControls) {
                        OnScreenControllerSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.analogDeadzone) {
                        AnalogDeadzoneSection()
                    }
                    #if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
                    CollapsibleSection(title: SettingsSectionTitle.deltaSkins) {
                        DeltaSkinsSection()
                    }
                    #endif
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }

    private var aboutTabContent: some View {
        tabScrollView {
            VStack(spacing: 16) {
                Text("settings.tab.about", bundle: .module)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                VStack(spacing: 16) {
                    CollapsibleSection(title: SettingsSectionTitle.socialLinks) {
                        SocialLinksSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.documentation) {
                        DocumentationSection()
                    }
                    CollapsibleSection(title: SettingsSectionTitle.roadmap) {
                        RoadmapSummarySection()
                        NavigationLink("View Full Roadmap →") {
                            RoadmapView()
                        }
                        .padding(.top, 4)
                    }
                    CollapsibleSection(title: SettingsSectionTitle.build) {
                        BuildSection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                    CollapsibleSection(title: SettingsSectionTitle.extraInfo) {
                        ExtraInfoSection()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }

    private var advancedTabContent: some View {
        tabScrollView {
            VStack(spacing: 16) {
                Text("settings.tab.advanced", bundle: .module)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                VStack(spacing: 16) {
                    CollapsibleSection(title: SettingsSectionTitle.advanced) {
                        AdvancedSection()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }
    #endif

    #if os(tvOS)
    /// Remembers the chosen section and opens it; the root reveals it after the search page has popped.
    private func selectSearchResult(_ entry: SettingsSearchEntry) {
        let section = entry.tvOSSection
        UserDefaults.standard.set(true, forKey: TVOSSettingsSectionState.storageKey(for: section))
        focusTargetSection = nil
        pendingSearchSection = section
    }

    private func revealPendingSearchSection(_ proxy: ScrollViewProxy) {
        guard let section = pendingSearchSection else { return }
        pendingSearchSection = nil
        Task { @MainActor in
            await Task.yield()
            withAnimation {
                proxy.scrollTo(section, anchor: .top)
            }
            focusTargetSection = section
        }
    }
    #endif
}

/// Row View for Settings with retrowave styling
struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var icon: SettingsIcon? = nil
    /// Controls the trailing chevron on tvOS. Set `false` for non-navigation rows (toggles, sliders, static info).
    var showChevron: Bool = true
    /// Maximum subtitle lines; `nil` uses the default of 5 so longer helper text is not truncated on iOS.
    var subtitleLineLimit: Int? = nil

    @ObservedObject private var themeManager = ThemeManager.shared
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #else
    /// Pointer hover (iPad / Mac); there is no hover on tvOS.
    @State private var isHovered = false
    #endif

    private var iconBorderWidth: CGFloat {
        #if os(tvOS)
        return isFocused ? 2 : 1
        #else
        return 1.5
        #endif
    }

    private var effectiveSubtitleLineLimit: Int {
        subtitleLineLimit ?? 5
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon with retrowave styling
            if let icon = icon {
                ZStack {
                    #if os(tvOS)
                    if isFocused {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.retroPink.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                    }
                    #endif

                    Circle()
                        .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.6))
                        #if os(tvOS)
                        .frame(width: 44, height: 44)
                        #else
                        .frame(width: 36, height: 36)
                        #endif
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: iconBorderWidth
                                )
                        )

                    icon.image
                        .resizable()
                        .scaledToFit()
                        #if os(tvOS)
                        .frame(width: 22, height: 22)
                        #else
                        .frame(width: 18, height: 18)
                        #endif
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }

            // Text content with retrowave styling
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isFocused ? .white : Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                    #else
                    .font(.body.weight(.medium))
                    .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                    #endif

                if let subtitle = subtitle {
                    Text(subtitle)
                        #if os(tvOS)
                        .font(.system(size: 15))
                        .foregroundStyle(isFocused ? .white.opacity(0.8) : Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.7))
                        #else
                        .font(.footnote)
                        .foregroundColor(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.8))
                        #endif
                        .lineLimit(effectiveSubtitleLineLimit)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // Value with retrowave styling
            if let value = value {
                Text(value)
                    #if os(tvOS)
                    .font(.system(size: 16, weight: .semibold))
                    #else
                    .font(.system(size: 14, weight: .medium))
                    #endif
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    #if os(tvOS)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    #else
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    #endif
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.4))
                            #if os(tvOS)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.retroBlue.opacity(0.5), Color.retroPurple.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            #endif
                    )
            }

            #if os(tvOS)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFocused ? Color.retroPink : Color.white.opacity(0.3))
            }
            #endif
        }
        #if os(tvOS)
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .buttonStyle(.plain) // remove default tvOS focus overlay; rely on our styling
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isFocused ?
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.12), Color.retroBlue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isFocused ?
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        #else
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.3))
                .opacity(isHovered ? 1.0 : 0.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

// MARK: - Section Views
private struct AppSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var iconManager = IconManager.shared

    var body: some View {
        Section {

            /// Information about PVSystems
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems",
                            subtitle: "Information on system cores, their bioses, links and stats.",
                            icon: .sfSymbol("square.stack.3d.down.forward"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            /// Links to projects
            NavigationLink(destination: CoreProjectsView()) {
                SettingsRow(title: "Cores",
                            subtitle: "Emulator cores provided by these projects.",
                            icon: .sfSymbol("square.3.layers.3d.middle.filled"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            NavigationLink(destination: ThemeSelectionView()) {
                SettingsRow(title: "Theme",
                            value: themeManager.currentPalette.description,
                            icon: .sfSymbol("paintpalette"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            #if !os(tvOS)
            /// App icon selection section — all users can browse, premium icons gated inside
            NavigationLink(destination: AppIconSelectorView()) {
                HStack {
                    SettingsRow(title: NSLocalizedString("settings.app.change_app_icon", bundle: .module, comment: ""),
                                icon: .sfSymbol("app"))
                    IconImage(
                        iconName: iconManager.currentIconName ?? "AppIcon",
                        size: 24
                    )
                }
            }
            #endif
        }
    }
}

/// Values the Core Options section would otherwise recompute every time the Emulation tab is rebuilt.
@MainActor
private enum RetroArchSettingsCache {
    /// The RetroArch framework is fixed for the life of the process, so scan the loaded bundles once.
    static let isRetroArchInstalled = PVRetroArchCoreManager.shared.isRetroArchInstalled

    private static var cachedResetState: (configModified: Date?, shouldReset: Bool)?

    /// `shouldResetConfig()` MD5-hashes both config files. The bundled one never changes, so the result only
    /// changes when the active config is rewritten (edit or reset); key the cache on its modification date.
    static func shouldResetConfig() async -> Bool {
        let manager = PVRetroArchCoreManager.shared
        let modified = manager.activeConfigURL.flatMap {
            (try? FileManager.default.attributesOfItem(atPath: $0.path))?[.modificationDate] as? Date
        }
        if let cachedResetState, cachedResetState.configModified == modified {
            return cachedResetState.shouldReset
        }
        let shouldReset = await manager.shouldResetConfig()
        cachedResetState = (modified, shouldReset)
        return shouldReset
    }
}

private struct CoreOptionsSection: View {
    @State private var shouldShowResetButton = false
    @State private var showResetConfirmation = false
    @State private var resetError: String? = nil
    @State private var showConfigEditor = false
    @Default(.coreLanguage) var coreLanguage

    var body: some View {
        Section {

            #if os(tvOS)
            NavigationLink(destination: CoreLanguageSelectionView(selection: $coreLanguage)) {
                HStack {
                    SettingsRow(title: "Core Language",
                                subtitle: "Language used by emulator cores. Default follows device locale.",
                                icon: .sfSymbol("globe"))
                    Spacer()
                    Text(coreLanguage.description)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.retroBlue, .retroPurple], startPoint: .leading, endPoint: .trailing)
                        )
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            LinearGradient(colors: [Color.retroBlue.opacity(0.5), Color.retroPurple.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
            }
            .retroFocusButtonStyle(showBorder: false)
            #else
            Picker(selection: $coreLanguage) {
                ForEach(CoreLanguageSetting.allCases, id: \.self) { lang in
                    Text(lang.description).tag(lang)
                }
            } label: {
                SettingsRow(title: "Core Language",
                            subtitle: "Language used by emulator cores. Default follows device locale.",
                            icon: .sfSymbol("globe"))
            }
            #endif

            NavigationLink(destination: CoreOptionsView().settingsSubpageTracking()) {
                SettingsRow(title: "Core Options",
                            subtitle: "Configure emulator core settings.",
                            icon: .sfSymbol("gearshape.2"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            if RetroArchSettingsCache.isRetroArchInstalled {
                NavigationLink(destination: RetroArchQuickSettingsView()) {
                    SettingsRow(
                        title: "RetroArch Settings",
                        subtitle: "Video, audio, notifications, performance, and more.",
                        icon: .sfSymbol("gearshape.2.fill")
                    )
                }
                #if os(tvOS)
                .retroFocusButtonStyle(showBorder: false)
                #endif
            }

            if shouldShowResetButton {
                Button(action: { showResetConfirmation = true }) {
                    SettingsRow(title: "Reset RetroArch Config",
                                subtitle: "Restore default RetroArch configuration.",
                                icon: .sfSymbol("arrow.uturn.backward.circle"))
                }
                .uiKitAlert(
                    "Reset RetroArch Config",
                    message: "This will overwrite your current RetroArch configuration with the default settings. Are you sure?",
                    isPresented: $showResetConfirmation,
                    preferredContentSize: CGSize(width: 500, height: 300)
                ) {
                    UIAlertAction(title: "Reset", style: .destructive) { _ in
                        resetRetroArchConfig()
                    }
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        showResetConfirmation = false
                    }
                }
            }

        }
        .task {
            shouldShowResetButton = await RetroArchSettingsCache.shouldResetConfig()
        }
        .uiKitAlert(
            "Reset Error",
            message: resetError ?? "",
            isPresented: .constant(resetError != nil),
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "OK", style: .default) { _ in
                resetError = nil
            }
        }
    }

    private func resetRetroArchConfig() {
        Task {
            guard let bundledURL = PVRetroArchCoreManager.shared.bundledConfigURL,
                  let activeURL = PVRetroArchCoreManager.shared.activeConfigURL else {
                return
            }

            do {
                try await PVRetroArchCoreManager.shared.copyConfigFile(from: bundledURL, to: activeURL)
                // Update the button state after successful reset
                shouldShowResetButton = await RetroArchSettingsCache.shouldResetConfig()
            } catch {
                resetError = "Failed to reset RetroArch config: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - tvOS Core Language Selection

#if os(tvOS)
/// RetroWave-styled language selection list for tvOS, replacing the clipped default Picker
private struct CoreLanguageSelectionView: View {
    @Binding var selection: CoreLanguageSetting
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView
                languageList
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 24)
        }
        .background(Color.black)
        .focusSection()
        .onExitCommand { dismiss() }
        .settingsSubpageTracking()
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.retroPink, .retroPurple], startPoint: .leading, endPoint: .trailing)
                )
            Text("Core Language")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.retroBlue, .retroPurple], startPoint: .leading, endPoint: .trailing)
                )
            Spacer()
        }
        .padding(.bottom, 24)
    }

    private var languageList: some View {
        VStack(spacing: 4) {
            ForEach(CoreLanguageSetting.allCases, id: \.self) { lang in
                LanguageSelectionRow(
                    language: lang,
                    isSelected: selection == lang
                ) {
                    selection = lang
                    dismiss()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.retroPurple.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

/// Individual row in the language selection list with RetroWave focus styling
private struct LanguageSelectionRow: View {
    let language: CoreLanguageSetting
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(language.description)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(colors: [.retroPink, .retroPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.retroPink.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.retroPink.opacity(0.35) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .retroFocusButtonStyle(showBorder: true)
    }
}
#endif

private struct SavesSection: View {

    @Default(.autoSave) var autoSave
    @Default(.timedAutoSaves) var timedAutoSaves
    @Default(.autoLoadSaves) var autoLoadSaves
    @Default(.askToAutoLoad) var askToAutoLoad
    @Default(.timedAutoSaveInterval) var timedAutoSaveInterval

    var timedAutosaveLabelText: String {
        "\(timedAutoSaveInterval/60.0) minutes between timed auto saves."
    }

    private static let oneMinute: TimeInterval = 60
    private static let thirtyMinutes: TimeInterval = 1800

    var body: some View {
        Section {
            savesToggles
#if !os(tvOS)
            timedAutosaveSlider
#else
            // TODO: TVOS Selection of autosave time
#endif
        }
    }

    @ViewBuilder
    private var savesToggles: some View {
        ThemedToggle(isOn: $autoSave) {
            SettingsRow(title: "Auto Save",
                        subtitle: "Auto-save game state on close. Must be playing for 30 seconds more.",
                        icon: .sfSymbol("autostartstop"),
                        showChevron: false)
        }
        ThemedToggle(isOn: $autoLoadSaves) {
            SettingsRow(title: "Auto Load Saves",
                        subtitle: "Automatically load the last save of a game if one exists. Disables the load prompt.",
                        icon: .sfSymbol("autostartstop"),
                        showChevron: false)
        }
        ThemedToggle(isOn: $askToAutoLoad) {
            SettingsRow(title: "Ask to Load Saves",
                        subtitle: "Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active.",
                        icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"),
                        showChevron: false)
        }
        ThemedToggle(isOn: $timedAutoSaves) {
            SettingsRow(title: "Timed Auto Saves",
                        subtitle: "Periodically create save states while you play.",
                        icon: .sfSymbol("clock.badge"),
                        showChevron: false)
        }
    }

#if !os(tvOS)
    @ViewBuilder
    private var timedAutosaveSlider: some View {
        HStack {
            Text("settings.saves.auto_save_time", bundle: .module)
            RetroWaveSlider(value: $timedAutoSaveInterval,
                           in: Self.oneMinute...Self.thirtyMinutes,
                           step: Self.oneMinute,
                           onEditingChanged: { _ in },
                           label: { Text("settings.saves.auto_save_time_label", bundle: .module) },
                           minimumValueLabel: { Text("settings.saves.min_1", bundle: .module) },
                           maximumValueLabel: { Text("settings.saves.min_30", bundle: .module) },
                           leadingIcon: {
                               Image(systemName: "hare")
                                   .foregroundColor(RetroTheme.retroBlue)
                           },
                           trailingIcon: {
                               Image(systemName: "tortoise")
                                   .foregroundColor(RetroTheme.retroBlue)
                           })
        }
        Text(timedAutosaveLabelText)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
#endif
}

private struct SocialLinksSection: View {

    let isAppStore: Bool = {
        AppState.shared.isAppStore
    }()

    var body: some View {
        Section {
            if !isAppStore {
                Link(destination: URL(string: "https://www.patreon.com/provenance")!) {
                    SettingsRow(title: "Patreon",
                                subtitle: "Support us on Patreon.",
                                icon: .named("patreon", PVUIBase.BundleLoader.myBundle))
                }
            }
            Link(destination: URL(string: "https://discord.gg/4TK7PU5")!) {
                SettingsRow(title: "Discord",
                            subtitle: "Join our Discord server for help and community chat.",
                            icon: .named("discord", PVUIBase.BundleLoader.myBundle))
            }
            Link(destination: URL(string: "https://twitter.com/provenanceapp")!) {
                SettingsRow(title: "X",
                            subtitle: "Follow us on X for release and other announcements.",
                            icon: .named("x", PVUIBase.BundleLoader.myBundle))
            }
            if !isAppStore {
                Link(destination: URL(string: "https://www.youtube.com/channel/UCKeN6unYKdayfgLWulXgB1w")!) {
                    SettingsRow(title: "YouTube",
                                subtitle: "Help tutorial videos and new feature previews.",
                                icon: .named("youtube", PVUIBase.BundleLoader.myBundle))
                }
            }
            Link(destination: URL(string: "https://github.com/Provenance-Emu/Provenance")!) {
                SettingsRow(title: "GitHub",
                            subtitle: "Check out GitHub for code, reporting bugs and contributing.",
                            icon: .named("github", PVUIBase.BundleLoader.myBundle))
            }
        }
    }
}

private struct DocumentationSection: View {
    var body: some View {
        Section {
            NavigationLink(destination: WikiHelpView()) {
                SettingsRow(title: "Help & Wiki",
                            subtitle: "Browse the Provenance wiki for guides, FAQs, and tips.",
                            icon: .sfSymbol("books.vertical.fill"))
            }
            Link(destination: URL(string: "https://provenance-emu.com/blog/")!) {
                SettingsRow(title: "Blog",
                            subtitle: "Release announcements and full changelogs and screenshots posted to our blog.",
                            icon: .sfSymbol("square.and.pencil"))
            }
        }
    }
}

private struct BuildSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
        Section {
            SettingsRow(title: "Version",
                        subtitle: "Current app version.",
                        value: viewModel.versionText,
                        icon: .sfSymbol("info.circle"),
                        showChevron: false)
            SettingsRow(title: "Build",
                        subtitle: "Internal build number.",
                        value: viewModel.buildVersion,
                        icon: .sfSymbol("hammer"),
                        showChevron: false)
            SettingsRow(title: "Git Revision",
                        subtitle: "Source code version.",
                        value: viewModel.gitRevision,
                        icon: .sfSymbol("chevron.left.forwardslash.chevron.right"),
                        showChevron: false)
            SettingsRow(title: "Built By",
                        subtitle: "Developer who built this version.",
                        value: viewModel.buildUser,
                        icon: .sfSymbol("person"),
                        showChevron: false)
            SettingsRow(title: "Build Date",
                        subtitle: "When this version was compiled.",
                        value: viewModel.buildDate,
                        icon: .sfSymbol("calendar"),
                        showChevron: false)
        }
    }
}

private struct ExtraInfoSection: View {
    @State private var showLicensesAlert = false
    @State private var showPrivacyAlert = false
    @State private var showEULAAlert = false

    var body: some View {
        Section {
            #if os(tvOS)
            /// Open source licenses - Show alert on tvOS
            Button(action: { showLicensesAlert = true }) {
                SettingsRow(title: "Licenses",
                            subtitle: "Open-source libraries Provenance uses and their respective licenses.",
                            icon: .sfSymbol("doc.text"))
            }
            .retroFocusButtonStyle(showBorder: false)
            .alert(isPresented: $showLicensesAlert) {
                Alert(
                    title: Text("settings.legal.view_licenses_title", bundle: .module),
                    message: Text("settings.legal.view_licenses_message", bundle: .module),
                    dismissButton: .default(Text("OK", bundle: .module))
                )
            }

            /// Privacy Policy - Show URL on tvOS
            Button(action: { showPrivacyAlert = true }) {
                SettingsRow(title: "Privacy Policy",
                            subtitle: "View our privacy policy",
                            icon: .sfSymbol("hand.raised"))
            }
            .retroFocusButtonStyle(showBorder: false)
            .alert(isPresented: $showPrivacyAlert) {
                Alert(
                    title: Text("settings.legal.privacy_policy_title", bundle: .module),
                    message: Text("settings.legal.privacy_policy_message", bundle: .module),
                    dismissButton: .default(Text("OK", bundle: .module))
                )
            }

            /// End User License Agreement - Show URL on tvOS
            Button(action: { showEULAAlert = true }) {
                SettingsRow(title: "End User License Agreement (EULA)",
                            subtitle: "Apple's standard EULA",
                            icon: .sfSymbol("signature"))
            }
            .retroFocusButtonStyle(showBorder: false)
            .alert(isPresented: $showEULAAlert) {
                Alert(
                    title: Text("settings.legal.eula_title", bundle: .module),
                    message: Text("settings.legal.eula_message", bundle: .module),
                    dismissButton: .default(Text("OK", bundle: .module))
                )
            }
            #else
            /// Open source licenses
            NavigationLink(destination: LicensesView()) {
                SettingsRow(title: "Licenses",
                            subtitle: "Open-source libraries Provenance uses and their respective licenses.",
                            icon: .sfSymbol("doc.text"))
            }
            /// Privacy Policy
            Link(destination: URL(string: "https://provenance-emu.com/privacy/")!) {
                SettingsRow(title: "Privacy Policy",
                            subtitle: nil,
                            icon: .sfSymbol("hand.raised"))
            }
            /// End User License Agreement
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                SettingsRow(title: "End User License Agreement (EULA)",
                            subtitle: nil,
                            icon: .sfSymbol("signature"))
            }
            #endif
        }
    }
}

private struct AudioSection: View {
    #if !os(tvOS)
    @Default(.volume) var volume
    @Default(.volumeHUD) var volumeHUD
    @Default(.respectMuteSwitch) var respectMuteSwitch
    #endif
    @Default(.pauseOnHeadphonesDisconnect) var pauseOnHeadphonesDisconnect
    var body: some View {
        Section {
            ThemedToggle(isOn: $pauseOnHeadphonesDisconnect) {
                SettingsRow(title: "Pause on Headphones Disconnect",
                            subtitle: "Auto-pause emulation when AirPods or Bluetooth headphones disconnect.",
                            icon: .sfSymbol("headphones"),
                            showChevron: false)
            }
            #if !os(tvOS)
            ThemedToggle(isOn: $respectMuteSwitch) {
                SettingsRow(title: "Respect Silent Mode",
                            subtitle: respectMuteSwitch ? "Disable game audio when system ringer is muted. Does not apply to headphones or external audio destinations." : "Play game audio when system ringer is muted. Does not apply to headphones or external audio destinations.",
                            icon: respectMuteSwitch ? .sfSymbol("speaker.slash.fill") : .sfSymbol("speaker.slash"))
            }
//            ThemedToggle(isOn: $volumeHUD) {
//                SettingsRow(title: "Volume HUD",
//                            subtitle: "Show volume indicator when changing volume.",
//                            icon: .sfSymbol("speaker.wave.2"))
//            }
            HStack {
                Text("settings.audio.volume", bundle: .module)
                RetroWaveSlider<Float>(value: $volume,
                                     in: 0...1,
                                     step: 0.1,
                                     onEditingChanged: { _ in },
                                     label: { Text("settings.audio.volume_level", bundle: .module) },
                                     minimumValueLabel: { Text("") },
                                     maximumValueLabel: { Text("") },
                                     leadingIcon: {
                                         Image(systemName: "speaker")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     },
                                     trailingIcon: {
                                         Image(systemName: "speaker.wave.3")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     })
            }
            Text("settings.audio.volume_description", bundle: .module)
                .font(.caption)
                .foregroundColor(.secondary)
            #endif
            // Add the new navigation link wrapped in PaidFeatureView
            PaidFeatureView {
                NavigationLink(destination: AudioEngineSettingsView()) {
                    SettingsRow(title: "Audio Engine",
                                subtitle: "Configure audio engine, buffer and latency settings.",
                                icon: .sfSymbol("waveform.circle"))
                }
                #if os(tvOS)
                .retroFocusButtonStyle(showBorder: false)
                #endif
            } lockedView: {
                SettingsRow(title: "Audio Engine",
                            subtitle: "Unlock to configure advanced audio settings.",
                            icon: .sfSymbol("lock.fill"),
                            showChevron: false)
            }
            .freemiumKitColorReset()
        }
    }
}

private struct VideoSection: View {
    @Default(.multiThreadedGL) var multiThreadedGL
    @Default(.multiSampling) var multiSampling
    @Default(.imageSmoothing) var imageSmoothing
    @Default(.showFPSCount) var showFPSCount
    @Default(.scalingMode) var scalingMode
    @Default(.vsyncEnabled) var vsyncEnabled
    @Default(.systemRegion) var systemRegion

    var body: some View {
        Section {
            ThemedToggle(isOn: $vsyncEnabled) {
                SettingsRow(title: "V-Sync",
                            subtitle: "Synchronizes the rendering frame rate with the monitor refresh rate.",
                            icon: vsyncEnabled ? .sfSymbol("tv.fill") : .sfSymbol("tv"),
                            showChevron: false)
            }
            ThemedToggle(isOn: $multiThreadedGL) {
                SettingsRow(title: "Multi-threaded Rendering",
                            subtitle: "Improves performance but may cause graphical glitches.",
                            icon: .sfSymbol("cpu"),
                            showChevron: false)
            }
            ThemedToggle(isOn: $multiSampling) {
                SettingsRow(title: "4X Multisampling GL",
                            subtitle: "Smoother graphics at the cost of performance.",
                            icon: .sfSymbol("square.stack.3d.up"),
                            showChevron: false)
            }
            // Wrap `scalingMode` so that the moment the user picks anything
            // we flip `userExplicitlySetScalingMode` to true. After that,
            // per-system defaults (e.g. `.stretch` for DS on tvOS) stop
            // substituting and the user's choice wins everywhere.
            Picker(selection: Binding(
                get: { scalingMode },
                set: { newValue in
                    scalingMode = newValue
                    if !Defaults[.userExplicitlySetScalingMode] {
                        Defaults[.userExplicitlySetScalingMode] = true
                    }
                }
            )) {
                ForEach(ScalingMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName)
                        .tag(mode)
                }
            } label: {
                SettingsRow(title: "Scaling Mode",
                            subtitle: scalingMode.subtitle,
                            icon: .sfSymbol(scalingMode.symbolName),
                            showChevron: false)
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.navigationLink)
            #endif
            Picker(selection: $systemRegion) {
                ForEach(SystemRegionPreference.allCases, id: \.self) { region in
                    Label(region.displayName, systemImage: region.symbolName)
                        .tag(region)
                }
            } label: {
                SettingsRow(title: "System Region",
                            subtitle: "Force a console region for region-aware cores (Sega Saturn). Auto detects from the disc; set a region so multi-region games don't default to Japan.",
                            icon: .sfSymbol(systemRegion.symbolName),
                            showChevron: false)
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.navigationLink)
            #endif
            ThemedToggle(isOn: $imageSmoothing) {
                SettingsRow(title: "Image Smoothing",
                            subtitle: "Smooth scaled graphics. Off for sharp pixels.",
                            icon: .sfSymbol("paintbrush.pointed"),
                            showChevron: false)
            }
            ThemedToggle(isOn: $showFPSCount) {
                SettingsRow(title: "FPS Counter",
                            subtitle: "Show frames per second counter.",
                            icon: .sfSymbol("speedometer"),
                            showChevron: false)
            }
            NavigationLink(destination: FilterSettingsView()) {
                SettingsRow(title: "Display Filters",
                            subtitle: "Configure CRT and LCD filter effects.",
                            icon: .sfSymbol("tv.fill"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            #if os(iOS)
            NavigationLink(destination: ExternalDisplaySettingsView()) {
                SettingsRow(title: "External Display",
                            subtitle: "Configure how the game appears on a connected TV or monitor.",
                            icon: .sfSymbol("tv.and.hifispeaker.fill"))
            }
            #endif
        }
    }
}

private struct RecordingSection: View {
    var body: some View {
#if os(iOS)
        Section {
            PaidFeatureView {
                NavigationLink(destination: RecordingSettingsView()) {
                    SettingsRow(
                        title: "Recording & Streaming",
                        subtitle: "Configure microphone, auto-save, HUD button, and clip duration.",
                        icon: .sfSymbol("record.circle")
                    )
                }
            } lockedView: {
                SettingsRow(
                    title: "Recording & Streaming",
                    subtitle: "Unlock to configure recording and streaming settings.",
                    icon: .sfSymbol("lock.fill")
                )
            }
            .freemiumKitColorReset()
        }
#endif
    }
}

#if os(tvOS)
/// Everything controller-related in one section, as shown on tvOS. iOS splits these into separate collapsible
/// sections (see `controllerTabContent`) because the combined list is ~40 rows long.
private struct ControllerSection: View {
    var body: some View {
        Group {
            subheading("settings.section.controllers")
            ControllerRowsSection()
            subheading("settings.section.haptics_rumble")
            HapticsRumbleSection()
            Text("DualSense / DS4 Features")
                .modifier(SubheadingStyle())
            DualSenseExtrasSection()
            subheading("settings.section.analog_deadzone")
            AnalogDeadzoneSection()
        }
    }

    /// The sections are no longer headed individually, so tvOS (one combined section) labels each group here.
    private func subheading(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .modifier(SubheadingStyle())
    }

    private struct SubheadingStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(.top, 12)
        }
    }
}
#endif

/// Controller selection, mapping and input-source rows.
private struct ControllerRowsSection: View {
    @Default(.use8BitdoM30) var use8BitdoM30
    @Default(.pauseButtonIsMenuButton) var pauseButtonIsMenuButton
    @Default(.controllerStyleNavigation) var controllerStyleNavigation

    var body: some View {
        Group {
            NavigationLink(destination: ControllerGuideView()) {
                SettingsRow(title: "Controller Guide",
                            subtitle: "Supported controllers, pairing steps, and platform notes.",
                            icon: .sfSymbol("books.vertical.fill"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            NavigationLink(destination: ControllerSettingsView()) {
                SettingsRow(title: "Controller Selection",
                            subtitle: "Configure external controller mappings.",
                            icon: .sfSymbol("gamecontroller"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            NavigationLink(destination: ICadeControllerView().tvOSSubpageFocusContainment()) {
                SettingsRow(title: "iCade / 8Bitdo",
                            subtitle: "Configure iCade and 8Bitdo controller settings.",
                            icon: .sfSymbol("keyboard"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            ThemedToggle(isOn: $use8BitdoM30) {
                SettingsRow(title: "Use 8BitDo M30 Mapping",
                            subtitle: "For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the PC Engine",
                            icon: .sfSymbol("arrow.triangle.swap"),
                            showChevron: false)
            }
            ThemedToggle(isOn: $pauseButtonIsMenuButton) {
                SettingsRow(title: "Pause/Menu button opens pause menu",
                            subtitle: "If on, the start/menu button on the controller will open the pause menu in addition to pausing the game",
                            icon: .sfSymbol("pause.rectangle"),
                            showChevron: false)
            }
            #if !os(tvOS)
            ThemedToggle(isOn: $controllerStyleNavigation) {
                SettingsRow(title: "Controller-Style Navigation",
                            subtitle: "Use the TV-style, keyboard/controller-driven library UI when a hardware keyboard is connected.",
                            icon: .sfSymbol("keyboard"),
                            showChevron: false)
            }
            #endif
            NavigationLink(destination: MouseInputSettingsView()) {
                SettingsRow(title: "Mouse Input",
                            subtitle: "Configure input source and sensitivity for mouse emulation",
                            icon: .sfSymbol("computermouse"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            #if !os(tvOS)
            NavigationLink(destination: KeyboardMappingView()) {
                SettingsRow(title: "Keyboard Mapping",
                            subtitle: "Remap keyboard keys to controller buttons.",
                            icon: .sfSymbol("keyboard.badge.ellipsis"))
            }
            #endif
        }
    }
}

/// Settings section for analog-stick deadzone coordination.
private struct AnalogDeadzoneSection: View {
    @Default(.analogDeadzone) var analogDeadzone
    @Default(.coreDeadzoneMode) var coreDeadzoneMode
    @State private var showingCompatibility = false

    private let modeLabels = ["Auto", "Universal", "Core-Managed"]
    private let modeDescriptions = [
        "Skip universal if core reports managing deadzone",
        "Always apply universal deadzone",
        "Let each core manage its own deadzone"
    ]

    var body: some View {
        Section(
            footer: Text(CoreDeadzoneCompatibilityCatalog.progressSummary)
                .foregroundColor(.secondary)
        ) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(title: "Universal Deadzone",
                            subtitle: "Dead region at center of analog sticks (0 = off). Applied on top of hardware deadzoning.",
                            icon: .sfSymbol("circle.dashed"),
                            showChevron: false)
                RetroWaveSlider(value: $analogDeadzone, in: 0.0...0.5, step: 0.01) {
                    Text("settings.controller.deadzone", bundle: .module)
                } minimumValueLabel: {
                    Image(systemName: "circle")
                } maximumValueLabel: {
                    Image(systemName: "circle.dashed")
                }
            }
            Picker("Core Deadzone Mode", selection: $coreDeadzoneMode) {
                ForEach(0..<modeLabels.count, id: \.self) { index in
                    VStack(alignment: .leading) {
                        Text(modeLabels[index])
                        Text(modeDescriptions[index])
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(index)
                }
            }
            .pickerStyle(.menu)
            Button {
                showingCompatibility = true
            } label: {
                HStack {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundColor(.accentColor)
                    Text("settings.controller.core_compatibility", bundle: .module)
                    Spacer()
                    let done = CoreDeadzoneCompatibilityCatalog.supportedEntries.count
                    let total = CoreDeadzoneCompatibilityCatalog.entries.count
                    Text(verbatim: "\(done)/\(total)")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #else
            .buttonStyle(.plain)
            #endif
            .sheet(isPresented: $showingCompatibility) {
                CoreDeadzoneCompatibilityView()
                    #if os(tvOS)
                    .settingsSheetDetachedFromSubpageDepth()
                    #endif
            }
        }
    }
}

/// Full-screen sheet listing all cores and their deadzone coordination status.
private struct CoreDeadzoneCompatibilityView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("settings.controller.coordinated", bundle: .module)) {
                    ForEach(CoreDeadzoneCompatibilityCatalog.supportedEntries) { entry in
                        CoreDeadzoneEntryRow(entry: entry)
                    }
                }
                if !CoreDeadzoneCompatibilityCatalog.pendingEntries.isEmpty {
                    Section(header: Text("settings.controller.coming_soon", bundle: .module)) {
                        ForEach(CoreDeadzoneCompatibilityCatalog.pendingEntries) { entry in
                            CoreDeadzoneEntryRow(entry: entry)
                        }
                    }
                }
                Section(footer: Text("Native: analog axes are deadzoned precisely before conversion. Coordinated: digital-threshold cores apply a max-wins rule so the user setting and core default never compound.")) {
                    EmptyView()
                }
            }
            #if !os(tvOS)
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationTitle("Deadzone Support")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(tvOS)
        .frame(minWidth: 700, minHeight: 750)
        #endif
    }
}

/// Single row in the compatibility list.
private struct CoreDeadzoneEntryRow: View {
    let entry: CoreDeadzoneCompatibilityCatalog.Entry

    private var levelColor: Color {
        switch entry.level {
        case .native:      return .green
        case .coordinated: return .blue
        case .partial:     return .orange
        case .pending:     return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.level.symbolName)
                    .foregroundColor(levelColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.displayName)
                        .font(.body)
                    Text(entry.systems.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(entry.level.label)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.15))
                    .foregroundColor(levelColor)
                    .clipShape(Capsule())
            }
            if let notes = entry.notes {
                Text(notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Comprehensive "Haptics & Rumble" settings section.
/// Consolidates the master toggle, per-source granular toggles, intensity slider,
/// DualSense adaptive-trigger toggle, "Test Rumble" button, and a link to Rumble Profiles.
private struct HapticsRumbleSection: View {
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.rumbleEnabled) var rumbleEnabled
    @Default(.rumbleDeviceEnabled) var rumbleDeviceEnabled
    @Default(.rumbleControllerEnabled) var rumbleControllerEnabled
    @Default(.dualSenseAdaptiveTriggersEnabled) var dualSenseAdaptiveTriggersEnabled
    @Default(.controllerHapticIntensity) var controllerHapticIntensity

    var body: some View {
        #if !os(tvOS)
        Section {
            ThemedToggle(isOn: $hapticFeedback) {
                SettingsRow(title: "Haptic Feedback",
                            subtitle: "Vibrate when pressing on-screen buttons.",
                            icon: .sfSymbol("iphone.radiowaves.left.and.right"),
                            showChevron: false)
            }
            ThemedToggle(isOn: $rumbleEnabled) {
                SettingsRow(title: "Game Rumble",
                            subtitle: "Master on/off for all in-game rumble events from emulator cores.",
                            icon: .sfSymbol("gamecontroller.fill"),
                            showChevron: false)
            }
            if rumbleEnabled {
                ThemedToggle(isOn: $rumbleDeviceEnabled) {
                    SettingsRow(title: "Device Taptic Engine",
                                subtitle: "Use the iPhone/iPad Taptic Engine for in-game rumble when no controller is connected.",
                                icon: .sfSymbol("iphone"),
                                showChevron: false)
                }
                ThemedToggle(isOn: $rumbleControllerEnabled) {
                    SettingsRow(title: "Controller Motors",
                                subtitle: "Fire rumble motors on DualSense, Xbox, Switch Pro, and DualShock 4 controllers.",
                                icon: .sfSymbol("dot.radiowaves.right"),
                                showChevron: false)
                }
                ThemedToggle(isOn: $dualSenseAdaptiveTriggersEnabled) {
                    SettingsRow(title: "DualSense Adaptive Triggers",
                                subtitle: "Apply per-system trigger resistance profiles on PS5 DualSense controllers.",
                                icon: .sfSymbol("l2.button.roundedtop.horizontal.fill"),
                                showChevron: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    SettingsRow(title: "Controller Rumble Intensity",
                                subtitle: "Motor strength for DualSense, Xbox, Switch, and DualShock 4 controllers.",
                                icon: .sfSymbol("waveform.path"),
                                showChevron: false)
                    RetroWaveSlider(value: $controllerHapticIntensity, in: 0.0...1.0, step: 0.05) {
                        Text("settings.controller.intensity", bundle: .module)
                    } minimumValueLabel: {
                        Image(systemName: "speaker")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3")
                    }
                    .padding(.horizontal)
                }
            }
            NavigationLink(destination: RumbleProfilesView()) {
                SettingsRow(title: "Rumble Profiles",
                            subtitle: "Customize per-system and per-controller haptic profiles.",
                            icon: .sfSymbol("slider.horizontal.3"))
            }
            TestRumbleButton()
        }
        #else
        // tvOS: always show rumble controls since external controllers are the primary input.
        Section {
            ThemedToggle(isOn: $rumbleEnabled) {
                SettingsRow(title: "Game Rumble",
                            subtitle: "Master on/off for all in-game rumble events from emulator cores.",
                            icon: .sfSymbol("gamecontroller.fill"),
                            showChevron: false)
            }
            if rumbleEnabled {
                ThemedToggle(isOn: $rumbleControllerEnabled) {
                    SettingsRow(title: "Controller Motors",
                                subtitle: "Fire rumble motors on connected controllers.",
                                icon: .sfSymbol("dot.radiowaves.right"),
                                showChevron: false)
                }
                ThemedToggle(isOn: $dualSenseAdaptiveTriggersEnabled) {
                    SettingsRow(title: "DualSense Adaptive Triggers",
                                subtitle: "Apply per-system trigger resistance profiles on PS5 DualSense controllers.",
                                icon: .sfSymbol("l2.button.roundedtop.horizontal.fill"),
                                showChevron: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    SettingsRow(title: "Controller Rumble Intensity",
                                subtitle: "Motor strength for connected controllers.",
                                icon: .sfSymbol("waveform.path"),
                                showChevron: false)
                    RetroWaveSlider(value: $controllerHapticIntensity, in: 0.0...1.0, step: 0.05) {
                        Text("settings.controller.intensity", bundle: .module)
                    } minimumValueLabel: {
                        Image(systemName: "speaker")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3")
                    }
                    .padding(.horizontal)
                }
            }
            NavigationLink(destination: RumbleProfilesView()) {
                SettingsRow(title: "Rumble Profiles",
                            subtitle: "Customize per-system and per-controller haptic profiles.",
                            icon: .sfSymbol("slider.horizontal.3"))
            }
            .retroFocusButtonStyle(showBorder: false)
            TestRumbleButton()
        }
        #endif
    }
}

/// DualSense / DualShock 4 extras section: light bar and microphone button settings.
private struct DualSenseExtrasSection: View {
    @Default(.controllerLightBarEnabled) var lightBarEnabled
    @Default(.dualSenseMicButtonAction) var micButtonAction

    var body: some View {
        Section {
            ThemedToggle(isOn: $lightBarEnabled) {
                SettingsRow(title: "Controller Light Bar",
                            subtitle: "Show a per-system color on the DualSense / DS4 light bar.",
                            icon: .sfSymbol("light.beacon.max.fill"),
                            showChevron: false)
            }
            Picker(selection: $micButtonAction,
                   label: SettingsRow(title: "Mic Button Action",
                                      subtitle: "Action performed when the DualSense microphone button is pressed.",
                                      icon: .sfSymbol("mic.fill"),
                                      showChevron: false)) {
                Text("Mute Audio").tag("muteAudio")
                Text("None").tag("none")
            }
            .pickerStyle(.menu)
        }
    }
}

/// Button that fires a short test rumble on all player-assigned controllers and optional device Taptic feedback.
private struct TestRumbleButton: View {
    @State private var isTesting = false
    @Default(.rumbleEnabled) private var rumbleEnabled
    @Default(.rumbleControllerEnabled) private var rumbleControllerEnabled
    @Default(.rumbleDeviceEnabled) private var rumbleDeviceEnabled

    var body: some View {
        Button {
            fireTestRumble()
        } label: {
            HStack {
                Image(systemName: isTesting ? "waveform" : "waveform.path")
                    .foregroundStyle(isTesting ? .green : .accentColor)
                    .animation(.easeInOut(duration: 0.2), value: isTesting)
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.controller.test_rumble", bundle: .module)
                        .font(.body)
                    Text("settings.controller.test_rumble_description", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(isTesting || !rumbleEnabled)
    }

    /// When controller rumble is enabled: clears unmapped player slots, registers slotted controllers without light bar / adaptive-trigger updates, then pulses motors.
    /// Respects `rumbleDeviceEnabled` for phone Taptic (including controller-rumble-off device-only test). Disabled when master `rumbleEnabled` is off.
    @MainActor
    private func fireTestRumble() {
        guard rumbleEnabled else { return }
        isTesting = true
        // Provenance player slots are 1-based; `GCControllerHapticsManager` uses 0-based indices like `PVEmulatorCore.controller1` → player 0.
        let live = PVControllerManager.shared.allLiveControllers
        let sortedSlots = live.sorted(by: { $0.key < $1.key })
        let occupiedZeroBased = Set(sortedSlots.map { $0.key - 1 })

        if rumbleControllerEnabled {
            if !sortedSlots.isEmpty {
                // Clear only unassigned indices when at least one slot is live — avoids wiping all light bar / haptic state if `allLiveControllers` is momentarily empty during gameplay.
                for player in 0..<8 where !occupiedZeroBased.contains(player) {
                    GCControllerHapticsManager.shared.register(controller: nil, forPlayer: player, effect: .fullSync)
                }
                for (pvSlot, controller) in sortedSlots {
                    GCControllerHapticsManager.shared.register(controller: controller, forPlayer: pvSlot - 1, effect: .hapticsEnginesOnly)
                }
                let params = GCControllerHapticsManager.RumbleParams(lowFrequency: 0.8, highFrequency: 0.5, duration: 0.4)
                for (pvSlot, _) in sortedSlots {
                    GCControllerHapticsManager.shared.rumble(player: pvSlot - 1, params: params)
                }
            }
        }

        #if !os(tvOS)
        if rumbleDeviceEnabled {
            if !rumbleControllerEnabled {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred(intensity: 0.8)
            } else {
                let anyMotorCapable = live.values.contains { $0.haptics != nil }
                if !anyMotorCapable {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.prepare()
                    generator.impactOccurred(intensity: 0.8)
                }
            }
        }
        #endif
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            isTesting = false
        }
    }
}

#if !os(tvOS)
private struct OnScreenControllerSection: View {
    @Default(.controllerOpacity) var controllerOpacity
    @Default(.controllerScale) var controllerScale
    @Default(.buttonTints) var buttonTints
    @Default(.allRightShoulders) var allRightShoulders
    @Default(.buttonVibration) var buttonVibration
    @Default(.buttonSound) var buttonSound
    @Default(.buttonPressEffect) var buttonPressEffect
    @Default(.stickyButtonsEnabled) var stickyButtonsEnabled
    @Default(.missingButtonsAlwaysOn) var missingButtonsAlwaysOn
    @Default(.onscreenJoypad) var onscreenJoypad
    @Default(.onscreenJoypadWithKeyboard) var onscreenJoypadWithKeyboard
    @Default(.hideOnScreenControlsWithController) var hideOnScreenControlsWithController
#if !os(tvOS)
    @Default(.movableButtons) var movableButtons
#endif

    var body: some View {
        Section {
            HStack {
                Text("settings.on_screen.controller_opacity", bundle: .module)
                RetroWaveSlider<Double>(value: $controllerOpacity,
                                     in: 0...1.0,
                                     step: 0.05,
                                     onEditingChanged: { _ in },
                                     label: { Text("settings.on_screen.transparency_description", bundle: .module) },
                                     minimumValueLabel: { Text("") },
                                     maximumValueLabel: { Text("") },
                                     leadingIcon: {
                                         Image(systemName: "sun.min")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     },
                                     trailingIcon: {
                                         Image(systemName: "sun.max")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     })
            }
            HStack {
                Text("Controller Scale")
                RetroWaveSlider<Double>(value: $controllerScale,
                                     in: 0.5...2.0,
                                     step: 0.05,
                                     onEditingChanged: { _ in },
                                     label: { Text("Scales on-screen controls and adjusts the game viewport so nothing clips or overlaps.") },
                                     minimumValueLabel: { Text("") },
                                     maximumValueLabel: { Text("") },
                                     leadingIcon: {
                                         Image(systemName: "minus.magnifyingglass")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     },
                                     trailingIcon: {
                                         Image(systemName: "plus.magnifyingglass")
                                             .foregroundColor(RetroTheme.retroBlue)
                                     })
            }
            ThemedToggle(isOn: $hideOnScreenControlsWithController) {
                SettingsRow(title: "Auto-Hide with Controller",
                            subtitle: "Hide on-screen controls when a physical game controller is connected.",
                            icon: .sfSymbol("gamecontroller"))
            }
            ThemedToggle(isOn: $buttonTints) {
                SettingsRow(title: "Button Colors",
                            subtitle: "Show colored buttons matching original hardware.",
                            icon: .sfSymbol("paintpalette"))
            }
            ThemedToggle(isOn: $allRightShoulders) {
                SettingsRow(title: "All Right Shoulder Buttons",
                            subtitle: "Show all shoulder buttons on the right side.",
                            icon: .sfSymbol("l.joystick.tilt.right"))
            }
            ThemedToggle(isOn: $buttonVibration) {
                SettingsRow(title: "Haptic Feedback",
                            subtitle: "Vibrate when pressing on-screen buttons.",
                            icon: .sfSymbol("hand.point.up.braille"))
            }
            ThemedToggle(isOn: $missingButtonsAlwaysOn) {
                SettingsRow(title: "Missing Buttons Always On",
                            subtitle: "Always show buttons not present on original hardware.",
                            icon: .sfSymbol("l.rectangle.roundedbottom"))
            }

            ThemedToggle(isOn: $onscreenJoypad) {
                SettingsRow(title: "On-Screen Joystick",
                            subtitle: "Show a touch Joystick pad on supported systems.",
                            icon: .sfSymbol("l.joystick.tilt.left.fill"))
            }
            ThemedToggle(isOn: $onscreenJoypadWithKeyboard) {
                SettingsRow(title: "On-Screen Joypad with keyboard",
                            subtitle: "Show a touch Joystick pad on supported systems when the P1 controller is 'Keyboard'. Useful on iPad OS for systems with an analog joystick (N64, PSX, etc.)",
                            icon: .sfSymbol("keyboard.badge.eye"))
            }
            ThemedToggle(isOn: $movableButtons) {
                SettingsRow(title: "Movable Buttons",
                            subtitle: "Allow player to move on screen controller buttons. Tap with 3-fingers 3 times to toggle.",
                            icon: .sfSymbol("arrow.up.and.down.and.arrow.left.and.right"))
            }
            ThemedToggle(isOn: $stickyButtonsEnabled) {
                SettingsRow(title: "Sticky Buttons",
                            subtitle: "Double-tap a button to lock it held down. Double-tap again to release. Useful for auto-run in platformers.",
                            icon: .sfSymbol("lock.rectangle"))
            }

        }
    }

    private func playButtonSound(_ sound: ButtonSound) {
        PVUIBase.ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
    }
}
#endif

private struct LibrarySection: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
        Section {
            //#if canImport(PVWebServer)
            //            Button(action: viewModel.launchWebServer) {
            //                SettingsRow(title: "Launch Web Server",
            //                            subtitle: "Transfer ROMs and saves over WiFi.",
            //                            icon: .sfSymbol("xserve"))
            //            }
            //#endif
            NavigationLink(destination: AppearanceView()) {
                SettingsRow(title: "Appearance",
                            subtitle: "Visual options for Game Library",
                            icon: .sfSymbol("eye"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            NavigationLink(destination: ExternalEmulatorMigrationView()) {
                #if os(tvOS)
                SettingsRow(title: NSLocalizedString("migration.settings.nav_title", bundle: .module, comment: ""),
                            subtitle: NSLocalizedString("migration.settings.row.subtitle.tvos", bundle: .module, comment: ""),
                            icon: .sfSymbol("arrow.triangle.2.circlepath"))
                #else
                SettingsRow(title: NSLocalizedString("migration.settings.nav_title", bundle: .module, comment: ""),
                            subtitle: NSLocalizedString("migration.settings.row.subtitle.ios", bundle: .module, comment: ""),
                            icon: .sfSymbol("arrow.triangle.2.circlepath"))
                #endif
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
        }
    }
}

private struct LibrarySection2: View {
    @ObservedObject var viewModel: PVSettingsViewModel
    @Default(.autoNormalizeROMTitles) var autoNormalizeROMTitles
    @Default(.unsupportedCores) var unsupportedCores
    @State private var showSaveImportWizard = false

    var body: some View {
        Section {

            #if os(tvOS)
                // Cloud Sync Settings
                NavigationLink(destination: CloudSyncSettingsView()) {
                    SettingsRow(title: "Cloud Sync Settings",
                                 subtitle: "Manage CloudKit and iCloud Drive sync settings",
                                 icon: .sfSymbol("icloud"))
                }
                .retroFocusButtonStyle(showBorder: false)
                NavigationLink(destination: BackupRestoreView()) {
                    SettingsRow(title: "Backup & Restore",
                                subtitle: "Manually back up and restore saves, database, and artwork.",
                                icon: .sfSymbol("archivebox"))
                }
                .retroFocusButtonStyle(showBorder: false)
            #else
//            if viewModel.showFeatureFlagsDebug {
                PaidFeatureView {
                    // Cloud Sync Settings
                    NavigationLink(destination: CloudSyncSettingsView()) {
                        SettingsRow(title: "Cloud Sync Settings",
                                     subtitle: "Manage CloudKit and iCloud Drive sync settings.",
                                     icon: .sfSymbol("icloud"))
                    }
                }  lockedView: {
                    SettingsRow(title: "Cloud Sync Settings",
                              subtitle: "Unlock to access CloudKit and iCloud Drive sync settings.",
                              icon: .sfSymbol("lock.fill"),
                              showChevron: false)
                }
                .freemiumKitColorReset()
//            }
            #endif

            #if !os(tvOS)
            NavigationLink(destination: BackupRestoreView()) {
                SettingsRow(title: "Backup & Restore",
                            subtitle: "Manually back up and restore saves, database, and artwork.",
                            icon: .sfSymbol("archivebox"))
            }
            #endif

            Button {
                showSaveImportWizard = true
            } label: {
                #if os(tvOS)
                let subtitle = "Saves sync automatically via iCloud. Tap to view guidance."
                #else
                let subtitle = "Import a save bundle or battery save from a .zip, .sav, .srm, or .ram file."
                #endif

                SettingsRow(title: "Import Saves",
                            subtitle: subtitle,
                            icon: .sfSymbol("square.and.arrow.down"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            .sheet(isPresented: $showSaveImportWizard) {
                SaveImportWizardView()
                    #if os(tvOS)
                    .settingsSheetDetachedFromSubpageDepth()
                    #endif
            }

            NavigationLink(destination: BatchArtworkMatchingView()) {
                SettingsRow(title: "Batch Artwork Matcher",
                            subtitle: "Find and apply artwork for multiple games at once.",
                            icon: .sfSymbol("photo.on.rectangle.angled"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            ThemedToggle(isOn: $autoNormalizeROMTitles) {
                SettingsRow(title: "Auto-Normalize Titles on Import",
                            subtitle: "Strip region/revision tags from ROM filenames (e.g. '(USA)', '[!]') when importing.",
                            icon: .sfSymbol("textformat.abc"),
                            showChevron: false)
            }

            ThemedToggle(isOn: $unsupportedCores) {
                SettingsRow(title: "Show Unsupported Cores",
                            subtitle: "Display experimental and unsupported cores.",
                            icon: .sfSymbol("exclamationmark.triangle"),
                            showChevron: false)
            }

            NavigationLink(destination: ROMTitleNormalizationView()) {
                SettingsRow(title: "Normalize Existing Library",
                            subtitle: "Preview and clean up ROM annotation tags from current library titles.",
                            icon: .sfSymbol("text.badge.checkmark"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            Button(action: viewModel.reimportROMs) {
                SettingsRow(title: "Scan ROM Directories",
                            subtitle: "Import new ROMs and update metadata without changing custom artwork or names.",
                            icon: .sfSymbol("magnifyingglass.circle"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            Button(action: viewModel.refreshGameLibrary) {
                SettingsRow(title: "Update Game Metadata",
                            subtitle: "Re-fetch artwork and info from the database. Custom artwork and names are preserved.",
                            icon: .sfSymbol("arrow.triangle.2.circlepath"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            Button(action: viewModel.emptyImageCache) {
                SettingsRow(title: "Clear Artwork Cache",
                            subtitle: "Delete cached artwork to free up space. Images re-download automatically.",
                            icon: .sfSymbol("photo.trianglebadge.exclamationmark"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            Button(role: .destructive, action: viewModel.resetData) {
                SettingsRow(title: "Reset Library",
                            subtitle: "Delete all game data, settings, and custom artwork, then re-import from scratch.",
                            icon: .sfSymbol("trash.slash"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
        }
        .alert(item: $viewModel.pendingLibraryAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: action.isDestructive
                    ? .destructive(Text(action.confirmButtonTitle)) { viewModel.confirmLibraryAction() }
                    : .default(Text(action.confirmButtonTitle)) { viewModel.confirmLibraryAction() },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct AdvancedSection: View {
    var body: some View {
        Group {
            #if canImport(FreemiumKit)
            PaidStatusView(style: .decorative(icon: .star))
                .freemiumKitColorReset()
            #endif
            AdvancedTogglesView()

            // App Group File Browser for debugging
            NavigationLink(destination: AppGroupFileBrowserView()) {
                SettingsRow(title: "App Group File Browser",
                            subtitle: "Browse files in the app group container for debugging.",
                            icon: .sfSymbol("folder.badge.gear"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            #if os(tvOS)
            // TopShelf Log Viewer
            NavigationLink(destination: TopShelfLogView()) {
                SettingsRow(title: "TopShelf Log",
                            subtitle: "View logs from the TopShelf extension.",

                            icon: .sfSymbol("doc.text.magnifyingglass"))
            }
            .retroFocusButtonStyle(showBorder: false)
            #endif

            #if !os(tvOS)
            // Spotlight Debug View
            NavigationLink(destination: SpotlightDebugView()) {
                SettingsRow(title: "Spotlight Debug",
                            subtitle: "View and manage Spotlight indexing for games and save states.",
                            icon: .sfSymbol("magnifyingglass.circle"))
            }
            #endif

            // Log view
            NavigationLink(destination: RetroLogView().tvOSSubpageFocusContainment()) {
                SettingsRow(title: "Logs",
                            subtitle: "View, search, and export app logs.",
                            icon: .sfSymbol("doc.text.magnifyingglass"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            // RetroArch log file browser
            NavigationLink(destination: RetroArchLogBrowserView()) {
                SettingsRow(title: "RetroArch Logs",
                            subtitle: "Browse, view, share, and delete RetroArch log files.",
                            icon: .sfSymbol("doc.text.below.ecg"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            // Session log file browser
            NavigationLink(destination: PVLogSessionBrowserView()) {
                SettingsRow(title: "Session Logs",
                            subtitle: "View and manage file-based session log archives.",
                            icon: .sfSymbol("doc.on.doc"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif

            SecretSettingsRow()
        }
    }
}

private struct DeltaSkinsSection: View {
    @Default(.buttonPressEffect) var buttonPressEffect
    @Default(.buttonSound) var buttonSound
    @Default(.skinMode) var skinMode

    var body: some View {
        Section {
            VStack {
                Text("settings.skins.skin_mode", bundle: .module)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.retroBlue)
                    .shadow(color: .retroPink.opacity(0.8), radius: 2, x: 1, y: 1)

                Picker("Select skin mode", selection: $skinMode) {
                    ForEach(SkinMode.allCases, id: \.self) { theme in
                        Text(theme.rawValue.uppercased()).tag(theme)
                    }
                }
#if !os(tvOS)
                .pickerStyle(.wheel)
#else
                .pickerStyle(.automatic)
#endif
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .background(Color.retroBlack.opacity(0.5))
                .cornerRadius(8)

                Text(skinMode.subtitle)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.retroBlue)
                    .shadow(color: .retroPink.opacity(0.8), radius: 2, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity)


            // Button to select skins
            NavigationLink {
                SystemSkinBrowserView()
                    .settingsSubpageTracking()
            } label: {
                SettingsRow(title: "Select Controller Skins",
                            subtitle: "Choose controller skins for each system and orientation.",
                            icon: .sfSymbol("gamecontroller.fill"))
            }

            // Button to manage skins
            NavigationLink {
                DeltaSkinListView(manager: DeltaSkinManager.shared)
                    .settingsSubpageTracking()
            } label: {
                SettingsRow(title: "Manage Controller Skins",
                            subtitle: "View, import, and delete controller skins.",
                            icon: .sfSymbol("folder.badge.gearshape"))
            }

            // Button to browse the skin catalog
            NavigationLink {
                SkinCatalogBrowserView()
                    .settingsSubpageTracking()
            } label: {
                SettingsRow(title: "Skin Browser",
                            subtitle: "Browse and download skins from the community catalog.",
                            icon: .sfSymbol("square.grid.2x2"))
            }

            // Button to open skin documentation in the built-in wiki
            NavigationLink {
                WikiPageView(path: "info/skins-guide.md", title: "Skin Documentation")
                    .settingsSubpageTracking()
            } label: {
                SettingsRow(title: "Skin Documentation",
                            subtitle: "Learn how to create and install controller skins.",
                            icon: .sfSymbol("book.pages"))
            }

            buttonSoundEFfect

            buttonTouchFeedback

            DeltaStylesLinkView()
        }
    }

    var buttonTouchFeedback: some View {
        // Button Press Effect Picker
        NavigationLink {
            ButtonEffectPickerView(buttonPressEffect: $buttonPressEffect)
        } label: {
            SettingsRow(title: "Button Effect Style",
                       subtitle: buttonPressEffect.description,
                       icon: .sfSymbol("circle.circle"))
        }
    }

    var buttonSoundEFfect: some View {
        // Button Sound Effect Picker
        NavigationLink {
            ButtonSoundPickerView(buttonSound: $buttonSound, playSound: playButtonSound)
        } label: {
            SettingsRow(title: "Button Sound Effect",
                        subtitle: buttonSound.description,
                        icon: .sfSymbol("speaker.wave.2"))
        }
    }


    private func playButtonSound(_ sound: ButtonSound) {
        PVUIBase.ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
    }
}

/// View component for linking to DeltaStyles website
private struct DeltaStylesLinkView: View {
    @State private var showSafariView = false
    @ObservedObject private var themeManager = ThemeManager.shared

    private let deltaStylesURL = URL(string: "https://deltastyles.com")!

    var body: some View {
        VStack(spacing: 12) {
            // Info label
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("settings.skins.download_more", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))

                Spacer()
            }
            .padding(.horizontal, 4)

            // Button to open DeltaStyles
            #if !os(tvOS)
            Button {
                showSafariView = true
            } label: {
                HStack {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("settings.skins.visit_deltastyles", bundle: .module)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
            .sheet(isPresented: $showSafariView) {
                SafariWebView(url: deltaStylesURL, entersReaderIfAvailable: false)
            }
            #else
            Link(destination: deltaStylesURL) {
                HStack {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("settings.skins.visit_deltastyles", bundle: .module)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
            #endif
        }
        .padding(.vertical, 8)
    }
}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
private struct RetroAchievementsSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel
    /// `nil` until the first `.task`: reading credentials hits the keychain, which must not run on every re-init.
    @State private var cheevosStatus: String?

    static func computeStatus() -> String {
        let mgr = RetroCredentialsManager.shared
        if mgr.hasValidSession, let username = mgr.loadCredentials()?.username {
            return "Logged in as \(username)"
        }
        return "Not logged in"
    }

    var body: some View {
        Section {
            NavigationLink(destination: RetroAchievementsView()) {
                SettingsRow(title: "RetroAchievements",
                            subtitle: cheevosStatus,
                            icon: .sfSymbol("trophy.fill"))
            }
            #if os(tvOS)
            .retroFocusButtonStyle(showBorder: false)
            #endif
            .task {
                cheevosStatus = RetroAchievementsSection.computeStatus()
            }
        }
    }
}

// MARK: - Plus Status Banner

#if canImport(FreemiumKit)
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
struct PlusStatusBanner: View {
    var body: some View {
        PaidFeatureView {
            // Subscriber view
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.plus.active_title", bundle: .module)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("settings.plus.thank_you", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.retroBlue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.retroPink.opacity(0.4),
                                        Color.retroPurple.opacity(0.4),
                                        Color.retroBlue.opacity(0.4)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        } lockedView: {
            // Non-subscriber view — tapping shows paywall via PaidFeatureView
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.plus.upgrade_title", bundle: .module)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("settings.plus.upgrade_description", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.retroPink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.retroPink.opacity(0.6),
                                        Color.retroPurple.opacity(0.6),
                                        Color.retroBlue.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .freemiumKitColorReset()
    }
}
#endif
