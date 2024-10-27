import SwiftUI
import PVLogging
import PVSwiftUI
import PVUIBase
import PVThemes

struct ContentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var appState: AppState
    let appDelegate: PVAppDelegate
    
    var body: some View {
        Group {
            switch appState.bootupStateManager.currentState {
            case .completed:
                ZStack {
                    MainView(appDelegate: appDelegate)
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
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

    }
}
