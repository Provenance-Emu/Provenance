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
import Perception
import PVFeatureFlags
import Defaults
import AudioToolbox
import PVCheevos

#if os(tvOS)
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
/// ViewModifier that contains focus within a subpage to prevent accidental back navigation
/// when scrolling past content on tvOS. This prevents focus from escaping to parent tab bars.
@available(tvOS 14.0, *)
struct TVOSSubpageFocusContainment: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            // Contain focus within this view to prevent escape to parent tab bar
            .focusSection()
            // Handle Menu/Back button press to dismiss properly
            .onExitCommand {
                dismiss()
            }
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
}

#if os(tvOS)
/// A wrapper view for NavigationLink destinations on tvOS that properly contains focus
/// and prevents accidental back navigation when scrolling past content.
@available(tvOS 14.0, *)
struct TVOSSettingsSubpage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            content()
                .padding(.bottom, 50) // Extra padding to prevent focus escape at bottom
        }
        .focusSection() // Contain focus within this ScrollView
        .navigationTitle(title)
        .onExitCommand {
            // Handle Menu button to go back, not to parent's tab bar
            dismiss()
        }
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
                    Text("SETTINGS")
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

                    Text("CONFIGURE YOUR EXPERIENCE")
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

/// Premium collapsible section for tvOS settings
struct TVOSSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool = true
    @FocusState private var headerFocused: Bool

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
    @StateObject private var advancedSkinFeaturesFlag = PVFeatureFlagsManager.shared.flag(.advancedSkinFeatures)
    private let settingsNavigator = SettingsNavigator.shared
    var dismissAction: () -> Void
    weak var menuDelegate: PVMenuDelegate!

    @ObservedObject var conflictsController: PVGameLibraryUpdatesController

    @State public var showsDoneButton: Bool = true
    #if !os(tvOS)
    @State private var selectedTab: Int = 0
    #endif
    @State private var showCloudSync = false
    @State private var showWiki = false
    @State private var destinationCancellable: AnyCancellable?

    // Update initializer to take dismissAction
    public init(conflictsController: PVGameLibraryUpdatesController, menuDelegate: PVMenuDelegate, showsDoneButton: Bool = true, dismissAction: @escaping () -> Void) {
        self.conflictsController = conflictsController
        self.dismissAction = dismissAction
        _viewModel = StateObject(wrappedValue: PVSettingsViewModel(menuDelegate: menuDelegate, conflictsController: conflictsController))
        self.showsDoneButton = showsDoneButton
    }

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
                    },
                    tabItems: tabItems
                )
                .overlay(
                    // Custom navigation bar overlay
                    VStack {
                        HStack {
                            if showsDoneButton {
                                Button(action: { dismissAction() }) {
                                    Text("DONE")
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
                                    Text("HELP")
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

                            // Settings sections with premium styling
                            TVOSSettingsSection(title: "App", icon: "gearshape.fill") {
                                AppSection(viewModel: viewModel)
                                    .environmentObject(viewModel)
                            }

                            TVOSSettingsSection(title: "Core Options", icon: "cpu") {
                                CoreOptionsSection()
                            }

                            TVOSSettingsSection(title: "Saves", icon: "square.and.arrow.down.fill") {
                                SavesSection()
                            }

                            TVOSSettingsSection(title: "Audio", icon: "speaker.wave.3.fill") {
                                AudioSection()
                            }

                            TVOSSettingsSection(title: "Video", icon: "tv.fill") {
                                VideoSection()
                            }

                            TVOSSettingsSection(title: "Controller", icon: "gamecontroller.fill") {
                                ControllerSection()
                            }

                            TVOSSettingsSection(title: "RetroAchievements", icon: "trophy.fill") {
                                RetroAchievementsSection(viewModel: viewModel)
                                    .environmentObject(viewModel)
                            }

                            TVOSSettingsSection(title: "Library", icon: "books.vertical.fill") {
                                LibrarySection(viewModel: viewModel)
                                    .environmentObject(viewModel)
                            }

                            TVOSSettingsSection(title: "Library Management", icon: "folder.badge.gearshape") {
                                LibrarySection2(viewModel: viewModel)
                                    .environmentObject(viewModel)
                            }

                            TVOSSettingsSection(title: "Advanced", icon: "wrench.and.screwdriver.fill") {
                                AdvancedSection()
                            }

                            TVOSSettingsSection(title: "Build", icon: "hammer.fill") {
                                BuildSection(viewModel: viewModel)
                                    .environmentObject(viewModel)
                            }

                            TVOSSettingsSection(title: "About", icon: "info.circle.fill") {
                                ExtraInfoSection()
                            }
                        }
                        .padding(.horizontal, 80)
                        .padding(.bottom, 80)
                    }
                    // Remove default tvOS focus highlight; rely on our RetroWave styling
                    .buttonStyle(TVOSSettingsSectionButtonStyle())
                    .focusSection()
                }
                #endif
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
        }
    }

#if os(tvOS)
    @Environment(\.tvMediaFocusCoordinator) private var tvMediaFocusCoordinator
#endif

    #if !os(tvOS)
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
        case .none:
            break
        }
    }

    private var generalTabContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("GENERAL")
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
                    CollapsibleSection(title: "App") {
                        AppSection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                    CollapsibleSection(title: "Library") {
                        LibrarySection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                    CollapsibleSection(title: "Library Management") {
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
        ScrollView {
            VStack(spacing: 16) {
                Text("EMULATION")
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
                    CollapsibleSection(title: "Core Options") {
                        CoreOptionsSection()
                    }
                    CollapsibleSection(title: "Saves") {
                        SavesSection()
                    }
                    CollapsibleSection(title: "Audio") {
                        AudioSection()
                    }
                    CollapsibleSection(title: "Video") {
                        VideoSection()
                    }
                    CollapsibleSection(title: "RetroAchievements") {
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
        ScrollView {
            VStack(spacing: 16) {
                Text("CONTROLLER")
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
                    CollapsibleSection(title: "Controller") {
                        ControllerSection()
                    }
                    #if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
                    CollapsibleSection(title: "Delta Skins") {
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
        ScrollView {
            VStack(spacing: 16) {
                Text("ABOUT")
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
                    CollapsibleSection(title: "Social Links") {
                        SocialLinksSection()
                    }
                    CollapsibleSection(title: "Documentation") {
                        DocumentationSection()
                    }
                    CollapsibleSection(title: "Roadmap") {
                        RoadmapSummarySection()
                        NavigationLink("View Full Roadmap →") {
                            RoadmapView()
                        }
                        .padding(.top, 4)
                    }
                    CollapsibleSection(title: "Build") {
                        BuildSection(viewModel: viewModel)
                            .environmentObject(viewModel)
                    }
                    CollapsibleSection(title: "Extra Info") {
                        ExtraInfoSection()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }

    private var advancedTabContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("ADVANCED")
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
                    CollapsibleSection(title: "Advanced") {
                        AdvancedSection()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
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

    @State private var isHovered = false
    @ObservedObject private var themeManager = ThemeManager.shared
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #endif

    private var iconBorderWidth: CGFloat {
        #if os(tvOS)
        return isFocused ? 2 : 1
        #else
        return 1.5
        #endif
    }

    private var iconShadowColor: Color {
        #if os(tvOS)
        return isFocused ? .retroPink.opacity(0.6) : .retroPink.opacity(0.2)
        #else
        return .retroPink.opacity(isHovered ? 0.5 : 0.2)
        #endif
    }

    private var iconShadowRadius: CGFloat {
        #if os(tvOS)
        return isFocused ? 10 : 5
        #else
        return 5
        #endif
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
                        .shadow(color: iconShadowColor, radius: iconShadowRadius)

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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                    #endif

                if let subtitle = subtitle {
                    Text(subtitle)
                        #if os(tvOS)
                        .font(.system(size: 15))
                        .foregroundStyle(isFocused ? .white.opacity(0.8) : Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.7))
                        .lineLimit(3)
                        #else
                        .font(.caption)
                        .foregroundColor(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.8))
                        .lineLimit(2)
                        #endif
                        .multilineTextAlignment(.leading)
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
            // Chevron for navigation items
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFocused ? Color.retroPink : Color.white.opacity(0.3))
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
        .shadow(color: isFocused ? Color.retroPink.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
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
        Section(header: Text("App")) {

            /// Information about PVSystems
            NavigationLink(destination: SystemSettingsView()) {
                SettingsRow(title: "Systems",
                            subtitle: "Information on system cores, their bioses, links and stats.",
                            icon: .sfSymbol("square.stack.3d.down.forward"))
            }

            /// Links to projects
            NavigationLink(destination: CoreProjectsView()) {
                SettingsRow(title: "Cores",
                            subtitle: "Emulator cores provided by these projects.",
                            icon: .sfSymbol("square.3.layers.3d.middle.filled"))
            }

            NavigationLink(destination: ThemeSelectionView()) {
                SettingsRow(title: "Theme",
                            value: themeManager.currentPalette.description,
                            icon: .sfSymbol("paintpalette"))
            }

            #if !os(tvOS)
            /// App icon selection section — all users can browse, premium icons gated inside
            NavigationLink(destination: AppIconSelectorView()) {
                HStack {
                    Image(systemName: "app")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.accentColor)
                    Text("Change App Icon")
                    Spacer()
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

private struct CoreOptionsSection: View {
    @State private var shouldShowResetButton = false
    @State private var showResetConfirmation = false
    @State private var resetError: String? = nil
    @State private var showConfigEditor = false

    var body: some View {
        Section(header: Text("Core Options")) {
            NavigationLink(destination: CoreOptionsView()) {
                SettingsRow(title: "Core Options",
                            subtitle: "Configure emulator core settings.",
                            icon: .sfSymbol("gearshape.2"))
            }

            if PVFeatureFlagsManager.shared.featureStates[.retroarchBuiltinEditor] ?? false {
                NavigationLink(destination: RetroArchConfigEditorWrapper()) {
                    SettingsRow(
                        title: "Edit RetroArch Config",
                        subtitle: "Modify advanced RetroArch settings.",
                        icon: .sfSymbol("gearshape.2.fill")
                    )
                }
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
            shouldShowResetButton = await PVRetroArchCoreManager.shared.shouldResetConfig()
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
                shouldShowResetButton = await PVRetroArchCoreManager.shared.shouldResetConfig()
            } catch {
                resetError = "Failed to reset RetroArch config: \(error.localizedDescription)"
            }
        }
    }
}

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
        SwiftUI.Section(header: Text("Saves")) {
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
                        icon: .sfSymbol("autostartstop"))
        }
        ThemedToggle(isOn: $timedAutoSaves) {
            SettingsRow(title: "Timed Auto Saves",
                        subtitle: "Periodically create save states while you play.",
                        icon: .sfSymbol("clock.badge"))
        }
        ThemedToggle(isOn: $autoLoadSaves) {
            SettingsRow(title: "Auto Load Saves",
                        subtitle: "Automatically load the last save of a game if one exists. Disables the load prompt.",
                        icon: .sfSymbol("autostartstop"))
        }
        ThemedToggle(isOn: $askToAutoLoad) {
            SettingsRow(title: "Ask to Load Saves",
                        subtitle: "Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active.",
                        icon: .sfSymbol("autostartstop.trianglebadge.exclamationmark"))
        }
    }

#if !os(tvOS)
    @ViewBuilder
    private var timedAutosaveSlider: some View {
        HStack {
            Text("Auto-save Time")
            RetroWaveSlider(value: $timedAutoSaveInterval,
                           in: Self.oneMinute...Self.thirtyMinutes,
                           step: Self.oneMinute,
                           onEditingChanged: { _ in },
                           label: { Text("Auto-save Time") },
                           minimumValueLabel: { Text("1m") },
                           maximumValueLabel: { Text("30m") },
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
        Section(header: Text("Social")) {
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
        Section(header: Text("Documentation")) {
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
        Section(header: Text("Build Information")) {
            SettingsRow(title: "Version",
                        subtitle: "Current app version.",
                        value: viewModel.versionText,
                        icon: .sfSymbol("info.circle"))
            SettingsRow(title: "Build",
                        subtitle: "Internal build number.",
                        value: viewModel.buildVersion,
                        icon: .sfSymbol("hammer"))
            SettingsRow(title: "Git Revision",
                        subtitle: "Source code version.",
                        value: viewModel.gitRevision,
                        icon: .sfSymbol("chevron.left.forwardslash.chevron.right"))
            SettingsRow(title: "Built By",
                        subtitle: "Developer who built this version.",
                        value: viewModel.buildUser,
                        icon: .sfSymbol("person"))
            SettingsRow(title: "Build Date",
                        subtitle: "When this version was compiled.",
                        value: viewModel.buildDate,
                        icon: .sfSymbol("calendar"))
        }
    }
}

private struct ExtraInfoSection: View {
    @State private var showLicensesAlert = false
    @State private var showPrivacyAlert = false
    @State private var showEULAAlert = false

    var body: some View {
        Section(header: Text("3rd Party & Legal")) {
            #if os(tvOS)
            /// Open source licenses - Show alert on tvOS
            Button(action: { showLicensesAlert = true }) {
                SettingsRow(title: "Licenses",
                            subtitle: "Open-source libraries Provenance uses and their respective licenses.",
                            icon: .sfSymbol("doc.text"))
            }
            .tvOSDisableFocusEffect()
            .buttonStyle(.plain) // remove default tvOS focus overlay; rely on our styling
            .alert(isPresented: $showLicensesAlert) {
                Alert(
                    title: Text("View Licenses"),
                    message: Text("Licenses are available in the iOS/iPadOS app or at:\nhttps://provenance-emu.com/licenses/"),
                    dismissButton: .default(Text("OK"))
                )
            }

            /// Privacy Policy - Show URL on tvOS
            Button(action: { showPrivacyAlert = true }) {
                SettingsRow(title: "Privacy Policy",
                            subtitle: "View our privacy policy",
                            icon: .sfSymbol("hand.raised"))
            }
            .tvOSDisableFocusEffect()
            .buttonStyle(.plain) // remove default tvOS focus overlay; rely on our styling
            .alert(isPresented: $showPrivacyAlert) {
                Alert(
                    title: Text("Privacy Policy"),
                    message: Text("Visit our privacy policy at:\nhttps://provenance-emu.com/privacy/"),
                    dismissButton: .default(Text("OK"))
                )
            }

            /// End User License Agreement - Show URL on tvOS
            Button(action: { showEULAAlert = true }) {
                SettingsRow(title: "End User License Agreement (EULA)",
                            subtitle: "Apple's standard EULA",
                            icon: .sfSymbol("signature"))
            }
            .tvOSDisableFocusEffect()
            .buttonStyle(.plain) // remove default tvOS focus overlay; rely on our styling
            .alert(isPresented: $showEULAAlert) {
                Alert(
                    title: Text("EULA"),
                    message: Text("Apple's standard EULA is available at:\nhttps://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
                    dismissButton: .default(Text("OK"))
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
        Section(header: Text("Audio")) {
            ThemedToggle(isOn: $pauseOnHeadphonesDisconnect) {
                SettingsRow(title: "Pause on Headphones Disconnect",
                            subtitle: "Auto-pause emulation when AirPods or Bluetooth headphones disconnect.",
                            icon: .sfSymbol("headphones"))
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
                Text("Volume")
                RetroWaveSlider<Float>(value: $volume,
                                     in: 0...1,
                                     step: 0.1,
                                     onEditingChanged: { _ in },
                                     label: { Text("Volume Level") },
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
            Text("System-wide volume level for games.")
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
            } lockedView: {
                SettingsRow(title: "Audio Engine",
                            subtitle: "Unlock to configure advanced audio settings.",
                            icon: .sfSymbol("lock.fill"))
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
    @Default(.nativeScaleEnabled) var nativeScaleEnabled
    @Default(.integerScaleEnabled) var integerScaleEnabled
    @Default(.vsyncEnabled) var vsyncEnabled

    var body: some View {
        Section(header: Text("Video")) {
            ThemedToggle(isOn: $vsyncEnabled) {
                SettingsRow(title: "V-Sync",
                            subtitle: "Synchronizes the rendering frame rate with the monitor refresh rate.",
                            icon: vsyncEnabled ? .sfSymbol("tv.fill") : .sfSymbol("tv"))
            }
            ThemedToggle(isOn: $multiThreadedGL) {
                SettingsRow(title: "Multi-threaded Rendering",
                            subtitle: "Improves performance but may cause graphical glitches.",
                            icon: .sfSymbol("cpu"))
            }
            ThemedToggle(isOn: $multiSampling) {
                SettingsRow(title: "4X Multisampling GL",
                            subtitle: "Smoother graphics at the cost of performance.",
                            icon: .sfSymbol("square.stack.3d.up"))
            }
            ThemedToggle(isOn: $nativeScaleEnabled) {
                SettingsRow(title: "Native Resolution",
                            subtitle: nativeScaleEnabled ? "Use the original console's resolution." : "Scale to fit the window.",
                            icon: .sfSymbol("arrow.up.left.and.arrow.down.right"))
            }
            ThemedToggle(isOn: $integerScaleEnabled) {
                SettingsRow(title: "Integer Scaling",
                            subtitle: "Scale by whole numbers only for pixel-perfect display.",
                            icon: .sfSymbol("square.grid.4x3.fill"))
            }
            ThemedToggle(isOn: $imageSmoothing) {
                SettingsRow(title: "Image Smoothing",
                            subtitle: "Smooth scaled graphics. Off for sharp pixels.",
                            icon: .sfSymbol("paintbrush.pointed"))
            }
            ThemedToggle(isOn: $showFPSCount) {
                SettingsRow(title: "FPS Counter",
                            subtitle: "Show frames per second counter.",
                            icon: .sfSymbol("speedometer"))
            }
            NavigationLink(destination: FilterSettingsView()) {
                SettingsRow(title: "Display Filters",
                            subtitle: "Configure CRT and LCD filter effects.",
                            icon: .sfSymbol("tv.fill"))
            }
        }
    }
}

private struct ControllerSection: View {
    @Default(.use8BitdoM30) var use8BitdoM30
    @Default(.pauseButtonIsMenuButton) var pauseButtonIsMenuButton
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.controllerHapticIntensity) var controllerHapticIntensity
    @Default(.analogDeadzone) var analogDeadzone
    @Default(.coreDeadzoneMode) var coreDeadzoneMode

    var body: some View {
        Group {
            Section(header: Text("Controllers")) {
                NavigationLink(destination: ControllerGuideView()) {
                    SettingsRow(title: "Controller Guide",
                                subtitle: "Supported controllers, pairing steps, and platform notes.",
                                icon: .sfSymbol("books.vertical.fill"))
                }
                NavigationLink(destination: ControllerSettingsView()) {
                    SettingsRow(title: "Controller Selection",
                                subtitle: "Configure external controller mappings.",
                                icon: .sfSymbol("gamecontroller"))
                }
                NavigationLink(destination: ICadeControllerView()) {
                    SettingsRow(title: "iCade / 8Bitdo",
                                subtitle: "Configure iCade and 8Bitdo controller settings.",
                                icon: .sfSymbol("keyboard"))
                }
                ThemedToggle(isOn: $use8BitdoM30) {
                    SettingsRow(title: "Use 8BitDo M30 Mapping",
                                subtitle: "For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the PC Engine",
                                icon: .sfSymbol("arrow.triangle.swap"))
                }
                ThemedToggle(isOn: $pauseButtonIsMenuButton) {
                    SettingsRow(title: "Pause/Menu button opens pause menu",
                                subtitle: "If on, the start/menu button on the controller will open the pause menu in addition to pausing the game",
                                icon: .sfSymbol("pause.rectangle"))
                }
            }

            #if !os(tvOS)
            ThemedToggle(isOn: $hapticFeedback) {
                SettingsRow(title: "Haptic Feedback",
                           subtitle: "Vibrate when pressing buttons.",
                           icon: .sfSymbol("iphone.radiowaves.left.and.right"))
            }
            #endif

            // On tvOS, always show Controller Rumble Intensity since external controllers
            // (DualSense, Xbox) are the primary input and phone haptic toggle is absent.
            // On iOS/iPadOS, gate it behind the Haptic Feedback toggle.
            #if os(tvOS)
            ControllerRumbleSlider(controllerHapticIntensity: $controllerHapticIntensity)
            #else
            if hapticFeedback {
                ControllerRumbleSlider(controllerHapticIntensity: $controllerHapticIntensity)
            }
            #endif
            #if !os(tvOS)
            OnScreenControllerSection()
            #endif
            AnalogDeadzoneSection(analogDeadzone: $analogDeadzone, coreDeadzoneMode: $coreDeadzoneMode)
        }
    }
}

/// Settings section for analog-stick deadzone coordination.
private struct AnalogDeadzoneSection: View {
    @Binding var analogDeadzone: Float
    @Binding var coreDeadzoneMode: Int
    @State private var showingCompatibility = false

    private let modeLabels = ["Auto", "Universal", "Core-Managed"]
    private let modeDescriptions = [
        "Skip universal if core reports managing deadzone",
        "Always apply universal deadzone",
        "Let each core manage its own deadzone"
    ]

    var body: some View {
        Section(
            header: Text("Analog Deadzone"),
            footer: Text(CoreDeadzoneCompatibilityCatalog.progressSummary)
                .foregroundColor(.secondary)
        ) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(title: "Universal Deadzone",
                            subtitle: "Dead region at center of analog sticks (0 = off). Applied on top of hardware deadzoning.",
                            icon: .sfSymbol("circle.dashed"))
                RetroWaveSlider(value: $analogDeadzone, in: 0.0...0.5, step: 0.01) {
                    Text("Deadzone")
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
                    Text("Core Compatibility")
                    Spacer()
                    let done = CoreDeadzoneCompatibilityCatalog.supportedEntries.count
                    let total = CoreDeadzoneCompatibilityCatalog.entries.count
                    Text("\(done)/\(total)")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCompatibility) {
                CoreDeadzoneCompatibilityView()
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
                Section(header: Text("Coordinated")) {
                    ForEach(CoreDeadzoneCompatibilityCatalog.supportedEntries) { entry in
                        CoreDeadzoneEntryRow(entry: entry)
                    }
                }
                if !CoreDeadzoneCompatibilityCatalog.pendingEntries.isEmpty {
                    Section(header: Text("Coming Soon")) {
                        ForEach(CoreDeadzoneCompatibilityCatalog.pendingEntries) { entry in
                            CoreDeadzoneEntryRow(entry: entry)
                        }
                    }
                }
                Section(footer: Text("Native: analog axes are deadzoned precisely before conversion. Coordinated: digital-threshold cores apply a max-wins rule so the user setting and core default never compound.")) {
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Deadzone Support")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

/// Slider for adjusting external controller rumble motor intensity.
/// Used by both tvOS (always visible) and iOS (gated behind haptic feedback toggle).
private struct ControllerRumbleSlider: View {
    @Binding var controllerHapticIntensity: Double

    var body: some View {
        Section(header: Text("Controller Rumble")) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(title: "Controller Rumble Intensity",
                            subtitle: "Motor strength for DualSense, Xbox, Switch, and DualShock 4 controllers.",
                            icon: .sfSymbol("waveform.path"))
                RetroWaveSlider(value: $controllerHapticIntensity, in: 0.0...1.0, step: 0.05) {
                    Text("Intensity")
                } minimumValueLabel: {
                    Image(systemName: "speaker")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3")
                }
                .padding(.horizontal)
            }
        }
    }
}

#if !os(tvOS)
private struct OnScreenControllerSection: View {
    @Default(.controllerOpacity) var controllerOpacity
    @Default(.buttonTints) var buttonTints
    @Default(.allRightShoulders) var allRightShoulders
    @Default(.buttonVibration) var buttonVibration
    @Default(.buttonSound) var buttonSound
    @Default(.buttonPressEffect) var buttonPressEffect
    @Default(.missingButtonsAlwaysOn) var missingButtonsAlwaysOn
    @Default(.onscreenJoypad) var onscreenJoypad
    @Default(.onscreenJoypadWithKeyboard) var onscreenJoypadWithKeyboard
#if !os(tvOS)
    @Default(.movableButtons) var movableButtons
#endif

    var body: some View {
        Section(header: Text("On-Screen Controller")) {
            HStack {
                Text("Controller Opacity")
                RetroWaveSlider<Double>(value: $controllerOpacity,
                                     in: 0...1.0,
                                     step: 0.05,
                                     onEditingChanged: { _ in },
                                     label: { Text("Transparency amount of on-screen controls overlays.") },
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
        Section(header: Text("Library")) {
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
        }
    }
}

private struct LibrarySection2: View {
    @ObservedObject var viewModel: PVSettingsViewModel

    var body: some View {
        Section(header: Text("Library Management")) {

            #if os(tvOS)
                // Cloud Sync Settings
                NavigationLink(destination: CloudSyncSettingsView()) {
                    SettingsRow(title: "Cloud Sync Settings",
                                 subtitle: "Manage CloudKit and iCloud Drive sync settings",
                                 icon: .sfSymbol("icloud"))
                }
                NavigationLink(destination: BackupRestoreView()) {
                    SettingsRow(title: "Backup & Restore",
                                subtitle: "Manually back up and restore saves, database, and artwork.",
                                icon: .sfSymbol("archivebox"))
                }
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
                              icon: .sfSymbol("lock.fill"))
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

            NavigationLink(destination: BatchArtworkMatchingView()) {
                SettingsRow(title: "Batch Artwork Matcher",
                            subtitle: "Find and apply artwork for multiple games at once.",
                            icon: .sfSymbol("photo.on.rectangle.angled"))
            }

            Button(action: viewModel.reimportROMs) {
                SettingsRow(title: "Scan ROM Directories",
                            subtitle: "Import new ROMs and update metadata without changing custom artwork or names.",
                            icon: .sfSymbol("magnifyingglass.circle"))
            }

            Button(action: viewModel.refreshGameLibrary) {
                SettingsRow(title: "Update Game Metadata",
                            subtitle: "Re-fetch artwork and info from the database. Custom artwork and names are preserved.",
                            icon: .sfSymbol("arrow.triangle.2.circlepath"))
            }

            Button(action: viewModel.emptyImageCache) {
                SettingsRow(title: "Clear Artwork Cache",
                            subtitle: "Delete cached artwork to free up space. Images re-download automatically.",
                            icon: .sfSymbol("photo.trianglebadge.exclamationmark"))
            }

            Button(role: .destructive, action: viewModel.resetData) {
                SettingsRow(title: "Reset Library",
                            subtitle: "Delete all game data, settings, and custom artwork, then re-import from scratch.",
                            icon: .sfSymbol("trash.slash"))
            }
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
            Section(header: Text("Advanced")) {
                #if canImport(FreemiumKit)
                PaidStatusView(style: .decorative(icon: .star))
                    .freemiumKitColorReset()
                    .listRowBackground(Color.accentColor)
                #endif
                AdvancedTogglesView()

                // App Group File Browser for debugging
                NavigationLink(destination: AppGroupFileBrowserView()) {
                    SettingsRow(title: "App Group File Browser",
                                subtitle: "Browse files in the app group container for debugging.",
                                icon: .sfSymbol("folder.badge.gear"))
                }

                #if os(tvOS)
                // TopShelf Log Viewer
                NavigationLink(destination: TopShelfLogView()) {
                    SettingsRow(title: "TopShelf Log",
                                subtitle: "View logs from the TopShelf extension.",

                                icon: .sfSymbol("doc.text.magnifyingglass"))
                }
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
                NavigationLink(destination: RetroLogView()) {
                    SettingsRow(title: "Logs",
                                subtitle: "View logs for debugging.",
                                icon: .sfSymbol("doc.text.magnifyingglass"))
                }

                SecretSettingsRow()
            }
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
                Text("SKIN MODE")
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
            } label: {
                SettingsRow(title: "Select Controller Skins",
                            subtitle: "Choose controller skins for each system and orientation.",
                            icon: .sfSymbol("gamecontroller.fill"))
            }

            // Button to manage skins
            NavigationLink {
                DeltaSkinListView(manager: DeltaSkinManager.shared)
            } label: {
                SettingsRow(title: "Manage Controller Skins",
                            subtitle: "View, import, and delete controller skins.",
                            icon: .sfSymbol("folder.badge.gearshape"))
            }

            // Button to browse the skin catalog
            NavigationLink {
                SkinCatalogBrowserView()
            } label: {
                SettingsRow(title: "Skin Browser",
                            subtitle: "Browse and download skins from the community catalog.",
                            icon: .sfSymbol("square.grid.2x2"))
            }

            // Button to open skin documentation in the built-in wiki
            NavigationLink {
                WikiPageView(path: "info/skins-guide.md", title: "Skin Documentation")
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

                Text("Download more skins from DeltaStyles")
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

                    Text("Visit DeltaStyles.com")
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

                    Text("Visit DeltaStyles.com")
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

    var body: some View {
        Section(header: Text("RetroAchievements")) {
            NavigationLink(destination: RetroAchievementsView()) {
                SettingsRow(title: "RetroAchievements",
                            subtitle: "Login and view your achievement progress",
                            icon: .sfSymbol("trophy.fill"))
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
                    Text("PROVENANCE PLUS ACTIVE")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Thank you for your support!")
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
                    Text("UPGRADE TO PROVENANCE PLUS")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Unlock cloud sync, premium themes & more")
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
