import SwiftUI
import Combine
import RealmSwift
import UniformTypeIdentifiers
import PVLibrary
import PVUIBase
import PVThemes
import PVFeatureFlags
#if canImport(PVWebServer)
import PVWebServer
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

/// The paged library's SwiftUI navigation and presentation root.
public struct PVLibraryRootView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigation: PVLibraryNavigation
    @ObservedObject private var sceneCoordinator = SceneCoordinator.shared
    @State private var navigationTask: Task<Void, Never>?
    @State private var netplayRequest: NetplayLibraryRequest?

    public init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>, updatesController: PVGameLibraryUpdatesController, gameImporter: GameImporter) {
        _navigation = StateObject(wrappedValue: PVLibraryNavigation(gameLibrary: gameLibrary, updatesController: updatesController, gameImporter: gameImporter))
    }

    public var body: some View {
        libraryContent
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
            .sheet(item: $navigation.sheet, onDismiss: navigation.didDismissSheet) { sheet in
                NavigationStack {
                    sheetContent(sheet)
                }
                .environmentObject(navigation.updatesController)
                .environmentObject(SettingsNavigator.shared)
                #if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
                #endif
            }
            .confirmationDialog("Select Import Source", isPresented: $navigation.showsImportSources, titleVisibility: .visible) {
                #if !os(tvOS)
                Button("Cloud & Local Files") { navigation.showsFileImporter = true }
                #endif
                #if canImport(PVWebServer)
                Button("Web Server") { startWebServer() }
                #endif
                if PVFeatureFlagsManager.shared.featureStates[.inAppFreeROMs] == true {
                    Button("Free ROMs") { navigation.sheet = .freeROMs }
                }
                Button("Import Queue") { navigation.didTapImports() }
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
            .confirmationDialog("Delete Game?", isPresented: Binding(
                get: { navigation.gameForDeletion != nil },
                set: { if !$0 { navigation.gameForDeletion = nil } }
            ), titleVisibility: .visible, presenting: navigation.gameForDeletion) { game in
                Button("Delete Game", role: .destructive) { navigation.confirmDeletion(game) }
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
            }
    }

    private var libraryContent: some View {
        PVLibraryDrawerHost(viewModel: navigation.viewModel) {
            NavigationStack {
                VStack(spacing: 0) {
                    LibraryHeader(viewModel: navigation.viewModel)
                    ConsolesWrapperView(consolesWrapperViewDelegate: navigation.tabs, viewModel: navigation.viewModel, rootDelegate: navigation)
                }
                #if !os(tvOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
            }
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
            List(navigation.availableCores, id: \.identifier) { core in
                Menu(core.displayName) {
                    Button("This Time") { navigation.chooseCore(core, preference: .once) }
                    Button("Always for This Game") { navigation.chooseCore(core, preference: .game) }
                    Button("Always for This System") { navigation.chooseCore(core, preference: .system) }
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
                navigation.viewModel.isMenuVisible.toggle()
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

    #if canImport(PVWebServer)
    private func startWebServer() {
        Task {
            await PVWebServerManager.shared.refreshFeatureFlag()
            do {
                guard try await PVWebServerManager.shared.start() else {
                    navigation.showMessage("Check your network connection and server settings.", title: "Unable to Start Web Server")
                    return
                }
                let message = await PVUIBase.PVWebServerAlertMessageBuilder.wikiMessageFromManager()
                #if os(tvOS)
                let viewTitle = "OK"
                #else
                let url = await PVWebServerManager.shared.serverURL
                let viewTitle = "Open Web Uploader"
                #endif
                sceneCoordinator.alertState.show(
                    title: "Web Server Active",
                    message: message,
                    type: .success,
                    primaryButtonTitle: viewTitle,
                    primaryAction: {
                        #if !os(tvOS)
                        if let url { openURL(url) }
                        #endif
                    },
                    secondaryButtonTitle: "Stop Server",
                    secondaryAction: {
                        Task {
                            await PVWebServerManager.shared.stop()
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

private enum LibraryChrome {
    static let cornerRadius: CGFloat = 16
    static let controlSize: CGFloat = 44
}

private struct LibraryHeader: View {
    @ObservedObject var viewModel: PVRootViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var accent: Color { Color(themeManager.currentPalette.defaultTintColor) }
    private var backgroundColor: Color { Color(themeManager.currentPalette.gameLibraryBackground) }

    private var usesCompactChrome: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
        HStack(spacing: usesCompactChrome ? 8 : 16) {
            Button {
                viewModel.isMenuVisible.toggle()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .frame(width: LibraryChrome.controlSize, height: LibraryChrome.controlSize)
            }
            .accessibilityLabel("Open Library Menu")
            Spacer(minLength: 0)
            LibraryHeaderTitle(
                iconName: viewModel.selectedConsole?.iconName,
                title: viewModel.selectedConsole?.name ?? "Home",
                accent: accent
            )
            Spacer(minLength: 0)
            Button {
                NotificationCenter.default.post(name: .pvShowSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: LibraryChrome.controlSize, height: LibraryChrome.controlSize)
            }
            .accessibilityLabel("Settings")
        }
        .buttonStyle(.plain)
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(accent)
        .padding(.horizontal, usesCompactChrome ? 12 : 8)
        .padding(.vertical, usesCompactChrome ? 0 : 4)
        .background {
            LibraryHeaderBackground(
                fillColor: backgroundColor,
                accent: accent,
                fillOpacity: reduceTransparency ? 1 : 0.94
            )
        }
        .padding(.horizontal, usesCompactChrome ? 8 : 16)
        .padding(.vertical, usesCompactChrome ? 0 : 8)
        .padding(.bottom, usesCompactChrome ? 4 : 0)
    }
}

private struct LibraryHeaderTitle: View {
    let iconName: String?
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            if let iconName {
                Image(iconName, bundle: PVUIBase.BundleLoader.myBundle)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "house.fill")
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.headline)
                .tracking(1.4)
                .lineLimit(1)
        }
        .shadow(color: accent.opacity(0.35), radius: 3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct LibraryHeaderBackground: View {
    let fillColor: Color
    let accent: Color
    let fillOpacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: LibraryChrome.cornerRadius)
            .fill(fillColor.opacity(fillOpacity))
            .overlay {
                RoundedRectangle(cornerRadius: LibraryChrome.cornerRadius)
                    .strokeBorder(accent.opacity(0.75), lineWidth: 2)
                    .shadow(color: accent.opacity(0.5), radius: 3)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
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
