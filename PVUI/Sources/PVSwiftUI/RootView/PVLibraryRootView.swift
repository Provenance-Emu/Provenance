import SwiftUI
import Combine
import RealmSwift
import UniformTypeIdentifiers
import PVLibrary
import PVUIBase
import PVThemes
import PVSettings
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PVWebServerHost)
import PVWebServerHost
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

/// The paged library's SwiftUI navigation and presentation root.
public struct PVLibraryRootView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigation: PVLibraryNavigation
    @ObservedObject private var sceneCoordinator = SceneCoordinator.shared
    @State private var navigationTask: Task<Void, Never>?
    @State private var netplayRequest: NetplayLibraryRequest?
    @State private var isWebServerRunning = false

    public init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>, updatesController: PVGameLibraryUpdatesController, gameImporter: GameImporter) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PVSkipOnboarding") {
            LocalNetworkOnboarding.markShown()
        }
        #endif
        _navigation = StateObject(wrappedValue: PVLibraryNavigation(gameLibrary: gameLibrary, updatesController: updatesController, gameImporter: gameImporter))
    }

    public var body: some View {
        libraryContent
            #if DEBUG && canImport(UIKit)
            .background {
                if ProcessInfo.processInfo.arguments.contains("-PVReviewGeometry") {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { recordReviewGeometry(geometry) }
                            .onChange(of: geometry.size) { _ in recordReviewGeometry(geometry) }
                    }
                }
            }
            #endif
            .tint(Color(themeManager.currentPalette.defaultTintColor))
            .preferredColorScheme(themeManager.currentPalette.dark ? .dark : .light)
            .netplayPresentation(item: $netplayRequest) { request in
                NetplayLibraryLobbyView(initialGameMD5: request.gameMD5)
            }
            .onReceive(NotificationCenter.default.publisher(for: NetplayLibraryRequest.notification)) { notification in
                guard let md5 = notification.object as? String else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    netplayRequest = NetplayLibraryRequest(gameMD5: md5)
                }
            }
            .modifier(LibrarySidebarSheetPresenter(viewModel: navigation.viewModel))
            .sheet(item: presentedBinding(.sheet), onDismiss: navigation.didDismissSheet) { sheet in
                presentedSheet(sheet)
            }
            #if os(iOS)
            // Settings covers the screen on iPad; a sheet there is a small centered card.
            .fullScreenCover(item: presentedBinding(.fullScreen), onDismiss: navigation.didDismissSheet) { sheet in
                presentedSheet(sheet)
            }
            #endif
            .pvAlert(isPresented: $navigation.showsImportSources) {
                PVAlert(title: "Select Import Source", style: .actionSheet, actions: importSourceActions)
            }
            #if !os(tvOS)
            .fileImporter(isPresented: $navigation.showsFileImporter, allowedContentTypes: [.data, .item], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    navigation.updatesController.handlePickedDocuments(urls)
                    navigation.didTapImports()
                case .failure(let error):
                    navigation.showMessage(error.localizedDescription, title: "Unable to Import Files")
                }
            }
            #endif
            .pvAlert(item: $navigation.gameForDeletion) { game in
                PVAlert(
                    title: "Delete Game?",
                    type: .warning,
                    style: .actionSheet,
                    actions: [
                        PVAlertAction("Delete Game", role: .destructive) { navigation.confirmDeletion(game) },
                        .cancel()
                    ]
                )
            }
            .onReceive(navigation.tabs.$selectedTab) { identifier in
                navigation.viewModel.selectedConsole = navigation.gameLibrary.system(identifier: identifier)?.freeze()
            }
            .onReceive(ScreenNavigator.shared.$destination) { destination in
                guard let destination else { return }
                navigation.handle(destination)
                ScreenNavigator.shared.clear()
            }
            .onReceive(LibraryNavigator.shared.$pendingAction) { action in
                guard case .console(let identifier) = action else { return }
                navigation.sheet = nil
                navigation.didTapConsole(with: identifier)
                LibraryNavigator.shared.clearPendingAction()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pvShowSettings)) { _ in
                navigation.didTapSettings()
            }
            #if canImport(PVWebServerHost)
            .onReceive(NotificationCenter.default.publisher(for: .pvWebServerStatusChanged).receive(on: DispatchQueue.main)) { notification in
                if let running = notification.userInfo?["isRunning"] as? Bool {
                    isWebServerRunning = running
                }
            }
            #endif
            .onReceive(GamepadManager.shared.eventPublisher.receive(on: DispatchQueue.main), perform: handleGamepad)
            .onChange(of: sceneCoordinator.currentScene) {
                navigationTask?.cancel()
                navigation.closeMenu()
            }
            .onChange(of: scenePhase) {
                if scenePhase != .active { navigationTask?.cancel() }
            }
            .onDisappear {
                navigationTask?.cancel()
                navigation.didDismissSheet()
            }
            .task {
                navigation.updatesController.resume()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-PVThemeLight") {
                    Defaults[.theme] = .standard(.light)
                    ThemeManager.applySavedTheme()
                } else if ProcessInfo.processInfo.arguments.contains("-PVThemeDark") {
                    Defaults[.theme] = .standard(.dark)
                    ThemeManager.applySavedTheme()
                } else if ProcessInfo.processInfo.arguments.contains("-PVThemeRetroWave") {
                    Defaults[.theme] = .retrowave
                    ThemeManager.applySavedTheme()
                }
                #endif
                #if canImport(PVWebServerHost)
                isWebServerRunning = await PVWebServerManager.shared.isRunning
                #endif
            }
    }

    #if DEBUG && canImport(UIKit)
    /// Records measured window insets for simulator review, without assuming device-specific values.
    private func recordReviewGeometry(_ geometry: GeometryProxy) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        let insets = window.safeAreaInsets
        let record: [String: Any] = [
            "windowWidth": window.bounds.width,
            "windowHeight": window.bounds.height,
            "contentWidth": geometry.size.width,
            "contentHeight": geometry.size.height,
            "safeAreaTop": insets.top,
            "safeAreaLeading": insets.left,
            "safeAreaBottom": insets.bottom,
            "safeAreaTrailing": insets.right,
            "palette": themeManager.currentPalette.name
        ]
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UIReviewGeometry", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("window-\(Int(window.bounds.width))x\(Int(window.bounds.height)).json"), options: .atomic)
        } catch {
            assertionFailure("Unable to record library review geometry: \(error)")
        }
    }
    #endif

    private var libraryContent: some View {
        PVLibraryDrawerHost(viewModel: navigation.viewModel) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    LibraryHeader(viewModel: navigation.viewModel, navigation: navigation)
                    NavigationStack {
                        ConsolesWrapperView(consolesWrapperViewDelegate: navigation.tabs, viewModel: navigation.viewModel, rootDelegate: navigation)
                            .environment(\.libraryBottomSafeAreaInset, geometry.safeAreaInsets.bottom)
                        #if !os(tvOS)
                        .toolbar(.hidden, for: .navigationBar)
                        #endif
                    }
                    #if os(iOS)
                    .ignoresSafeArea(.container, edges: .bottom)
                    #endif
                    // Paging children must not draw or receive taps over the library header.
                    .contentShape(Rectangle())
                    .clipped()
                }
            }
            .background(RetroTheme.RetroBackgroundView().environmentObject(themeManager).ignoresSafeArea())
        } menu: {
            SideMenuView(gameLibrary: navigation.gameLibrary, viewModel: navigation.viewModel, delegate: navigation, rootDelegate: navigation)
        }
        .overlay { LibraryProgressOverlay() }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: PVLibraryNavigation.Sheet) -> some View {
        switch sheet {
        case .settings:
            PVSettingsView(conflictsController: navigation.updatesController, menuDelegate: navigation, dismissAction: { navigation.sheet = nil })
        case .imports:
            ImportStatusView(updatesController: navigation.updatesController, gameImporter: navigation.gameImporter, delegate: navigation) {
                navigation.dismissAction()
            }
        case .freeROMs:
            FreeROMsView(onROMDownloaded: { _, url in
                navigation.updatesController.handlePickedDocuments([url])
            }, onDismiss: { navigation.sheet = .imports })
        case .saves:
            if let viewModel = navigation.continuesViewModel {
                ContinuesManagementView(viewModel: viewModel)
            }
        case .corePicker:
            List(navigation.corePickerItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Menu {
                        Button("This Time") { navigation.chooseCore(item.id, preference: .once) }
                        Button("Always for This Game") { navigation.chooseCore(item.id, preference: .game) }
                        Button("Always for This System") { navigation.chooseCore(item.id, preference: .system) }
                    } label: {
                        CorePickerMenuLabel(item: item)
                    }
                    if let reason = item.summary {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose Core")
        }
    }

    private func handleGamepad(_ event: GamepadEvent) {
        guard sceneCoordinator.currentScene == .main,
              !navigation.viewModel.isLibraryInputBlocked,
              !GamepadManager.shared.isModalAlertPresented else {
            navigationTask?.cancel()
            return
        }
        switch event {
        case .menuToggle(let pressed):
            if pressed {
                navigationTask?.cancel()
                navigation.viewModel.toggleMenu()
            }
        case .shoulderLeft(let pressed):
            repeatNavigation(pressed: pressed, isNext: false)
        case .shoulderRight(let pressed):
            repeatNavigation(pressed: pressed, isNext: true)
        default:
            break
        }
    }

    private func repeatNavigation(pressed: Bool, isNext: Bool) {
        navigationTask?.cancel()
        guard pressed, !navigation.viewModel.isMenuVisible else { return }
        navigation.navigate(isNext: isNext)
        navigationTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
                while !Task.isCancelled && !navigation.viewModel.isLibraryInputBlocked && !navigation.viewModel.isMenuVisible {
                    navigation.navigate(isNext: isNext)
                    try await Task.sleep(for: .milliseconds(150))
                }
            } catch { /* Releasing the shoulder button ends repeating navigation. */ }
        }
    }

    /// Choices in the "Select Import Source" sheet.
    private var importSourceActions: [PVAlertAction] {
        var actions: [PVAlertAction] = []
        #if !os(tvOS)
        actions.append(PVAlertAction("Cloud & Local Files") { navigation.showsFileImporter = true })
        #endif
        #if canImport(PVWebServerHost)
        actions.append(PVAlertAction(isWebServerRunning ? "Web Server — Running" : "Web Server") { startWebServer() })
        #endif
        actions.append(PVAlertAction("Free ROMs") { navigation.sheet = .freeROMs })
        actions.append(PVAlertAction("Import Queue") { navigation.didTapImports() })
        actions.append(.cancel())
        return actions
    }

    #if canImport(PVWebServerHost)
    private func startWebServer() {
        Task {
            do {
                guard try await PVWebServerManager.shared.start() else {
                    navigation.showMessage("Check your network connection and server settings.", title: "Unable to Start Web Server")
                    return
                }
                let message = await PVUIBase.PVWebServerAlertMessageBuilder.wikiMessageFromManager()
                isWebServerRunning = true
                #if !os(tvOS)
                let url = await PVWebServerManager.shared.serverURL
                let primaryTitle = "Open Web Uploader"
                let doneTitle: String? = "Done"
                #else
                let primaryTitle = "Done"
                let doneTitle: String? = nil
                #endif
                sceneCoordinator.alertState.show(
                    title: "Web Server Running",
                    message: message + "\n\nChoose Done to return to your library. The server and any uploads will keep running.",
                    type: .success,
                    primaryButtonTitle: primaryTitle,
                    primaryAction: {
                        #if !os(tvOS)
                        if let url { openURL(url) }
                        #endif
                    },
                    // Controller Cancel invokes the secondary action: keep it dismiss-only.
                    secondaryButtonTitle: doneTitle,
                    secondaryAction: {},
                    destructiveButtonTitle: "Stop Server",
                    destructiveAction: {
                        Task {
                            await PVWebServerManager.shared.stop()
                            isWebServerRunning = false
                            if !(await navigation.gameImporter.importQueue).isEmpty {
                                navigation.didTapImports()
                            }
                        }
                    }
                )
            } catch {
                navigation.showMessage(error.localizedDescription, title: "Unable to Start Web Server")
            }
        }
    }
    #endif
}

// MARK: - Sheet presentation

extension PVLibraryRootView {
    /// The current sheet when it is presented in `style`, else `nil`, so exactly one of the sheet and
    /// full-screen presenters shows `navigation.sheet`. A presenter only writes `nil` back when it owns the
    /// current item: SwiftUI may report a dismissal from the presenter that is handing over to the other.
    private func presentedBinding(_ style: SettingsPresentationStyle) -> Binding<PVLibraryNavigation.Sheet?> {
        Binding(
            get: {
                guard let sheet = navigation.sheet, sheet.presentationStyle == style else { return nil }
                return sheet
            },
            set: { newValue in
                if newValue == nil, navigation.sheet?.presentationStyle != style { return }
                navigation.sheet = newValue
            }
        )
    }

    private func presentedSheet(_ sheet: PVLibraryNavigation.Sheet) -> some View {
        NavigationStack {
            sheetContent(sheet)
        }
        .environmentObject(navigation.updatesController)
        .environmentObject(SettingsNavigator.shared)
        #if canImport(FreemiumKit)
        .environmentObject(FreemiumKit.shared)
        #endif
    }
}

/// Observe the sheet owner directly; navigation's nested ObservableObject does not forward its changes.
private struct LibrarySidebarSheetPresenter: ViewModifier {
    @ObservedObject var viewModel: PVRootViewModel

    func body(content: Content) -> some View {
        content.sheet(item: $viewModel.sidebarSheet, onDismiss: viewModel.didDismissSidebarSheet) { sheet in
            switch sheet {
            case .nearbyLibraries:
                #if os(iOS) || os(tvOS)
                NearbyLibrariesSheet()
                #else
                EmptyView()
                #endif
            case .networkPlay:
                NetplayLibraryLobbyView()
            }
        }
    }
}

private enum LibraryChrome {
    static let cornerRadius: CGFloat = 16
    static let controlSize: CGFloat = 44
    static let headerTopOpacity: Double = 0.78
    static let headerMidOpacity: Double = 0.55
}

private struct LibraryHeader: View {
    @ObservedObject var viewModel: PVRootViewModel
    @ObservedObject var navigation: PVLibraryNavigation
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    #if os(iOS)
    private var systemItems: [FloatingSystemSelectorItem] {
        navigation.gameLibrary.activeSystems.map { system in
            FloatingSystemSelectorItem(id: system.identifier, title: system.shortName,
                                       icon: Image(system.iconName, bundle: PVUIBase.BundleLoader.myBundle))
        }
    }
    #endif

    var body: some View {
        HStack(spacing: 4) {
            headerAction("line.3.horizontal", title: "Open Library Menu", action: viewModel.toggleMenu)

            Menu {
                ForEach(LibraryDestination.allCases) { destination in
                    Button {
                        navigation.didTapHome()
                        viewModel.libraryDestination = destination
                    } label: {
                        Label(destination.title, systemImage: destination.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Library").font(.system(size: 16, weight: .medium))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .overlay(alignment: .bottomLeading) {
                    Capsule().fill(Color.retroBlue).frame(width: 24, height: 1.5).offset(y: -8)
                }
            }
            .accessibilityLabel("Library destinations")
            #if os(iOS)
            if verticalSizeClass == .compact {
                FloatingSystemSelector(items: systemItems, selection: Binding(
                    get: { navigation.tabs.selectedTab },
                    set: { navigation.selectTab($0) }
                ))
                .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            #else
            Spacer(minLength: 0)
            #endif
            headerAction("tray.and.arrow.down", title: "Import Queue", action: navigation.didTapImports)
            headerAction("gearshape", title: "Settings", action: navigation.didTapSettings)
            headerAction("plus", title: "Add Games", action: navigation.didTapAddGames)
        }
        .buttonStyle(.plain)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
        .padding(.horizontal, 12)
        .background {
            if LibraryLayout.usesCompactPhoneChrome(verticalSizeClass) {
                let surface = Color(themeManager.currentPalette.gameLibraryBackground)
                // Translucent all the way up: the library backdrop continues behind the status bar.
                LinearGradient(
                    stops: [
                        .init(color: surface.opacity(LibraryChrome.headerTopOpacity), location: 0),
                        .init(color: surface.opacity(LibraryChrome.headerMidOpacity), location: 0.6),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.container, edges: .top)
            } else {
                Color.retroBlack.opacity(0.85).ignoresSafeArea(.container, edges: .top)
            }
        }
    }

    private func headerAction(_ symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(
                    width: LibraryLayout.usesCompactPhoneChrome(verticalSizeClass) ? 28 : 32,
                    height: LibraryLayout.usesCompactPhoneChrome(verticalSizeClass) ? 28 : 32
                )
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: LibraryChrome.controlSize, height: LibraryChrome.controlSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
    }
}

private struct LibraryProgressOverlay: View {
    @State private var state: HudState = .hidden
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Group {
            switch state {
            case .hidden:
                EmptyView()
            case .title(let title, let subtitle):
                panel(title: title, subtitle: subtitle, progress: nil)
            case .titleAndProgress(let title, let subtitle, let progress):
                panel(title: title, subtitle: subtitle, progress: Double(progress))
            }
        }
        .task {
            let states = await AppState.shared.hudCoordinator.$hudState.values
            for await newState in states {
                guard !Task.isCancelled else { return }
                state = newState
            }
        }
    }

    private func panel(title: String, subtitle: String?, progress: Double?) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.subheadline) }
            Button("Dismiss") {
                Task { await AppState.shared.hudCoordinator.updateHUD(.hidden) }
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: 320)
        .background((Color(themeManager.currentPalette.gameLibraryBackground)), in: RoundedRectangle(cornerRadius: LibraryChrome.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: LibraryChrome.cornerRadius)
                .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1)
                .shadow(color: .accentColor.opacity(0.4), radius: 4)
        }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .padding()
    }
}
