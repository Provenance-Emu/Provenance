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
    /// Use EnvironmentObject for bootup state manager
    @EnvironmentObject var bootupStateManager: AppBootupState
    /// Use EnvironmentObject for app delegate
    @EnvironmentObject var appDelegate: PVAppDelegate

    var bootupView: some View {
            // Show the bootup view
            BootupViewRetroWave()
                .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .transition(.opacity)
                .animation(.easeInOut, value: appState.bootupStateManager.currentState)
                .hideHomeIndicator()
            
//                BootupView()
//                    .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
//                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
    }
    
    /// Remove init since we're using environment objects now

    var body: some View {
        Group {
            switch bootupStateManager.currentState {
            case .completed:
                ZStack {
                    MainView()
                }
                .onAppear {
                    ILOG("ContentView: MainView appeared")
                }
            case .error(let error):
                ErrorView(error: error) {
                    appState.startBootupSequence()
                }
            default:
                bootupView
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
