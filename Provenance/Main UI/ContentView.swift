import SwiftUI
import PVLogging
import PVSwiftUI
import PVUIBase
import PVThemes
#if canImport(WhatsNewKit)
import WhatsNewKit
#endif

struct ContentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var appState: AppState
    /// Add explicit observation of bootup state
    @ObservedObject private var bootupStateManager: AppBootupState
    let appDelegate: PVAppDelegate

    init(appDelegate: PVAppDelegate) {
        self.appDelegate = appDelegate
        /// Initialize bootup state manager from app state
        self._bootupStateManager = ObservedObject(wrappedValue: AppState.shared.bootupStateManager)
    }

    var body: some View {
        Group {
            switch bootupStateManager.currentState {
            case .completed:
                ZStack {
                    MainView(appDelegate: appDelegate)
                }
                .onAppear {
                    ILOG("ContentView: MainView appeared")
                }
            case .error(let error):
                ErrorView(error: error) {
                    appState.startBootupSequence()
                }
            default:
                BootupView()
                    .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            ILOG("ContentView: Appeared")
        }
        .onChange(of: bootupStateManager.currentState) { state in
            ILOG("ContentView: Bootup state changed to \(state.localizedDescription)")
        }
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
#if canImport(WhatsNewKit)
        // Automatically present a WhatsNewView, if needed.
        // The WhatsNew that should be presented to the user
        // is automatically retrieved from the `WhatsNewEnvironment`
        .whatsNewSheet()
#endif
    }
}
