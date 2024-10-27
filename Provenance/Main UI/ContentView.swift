import SwiftUI
import PVLogging

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    let appDelegate: PVAppDelegate

    var body: some View {
        Group {
            switch appState.bootupStateManager.currentState {
            case .completed:
                MainView(appDelegate: appDelegate)
            case .error(let error):
                ErrorView(error: error) {
                    appState.startBootupSequence()
                }
            default:
                BootupView()
            }
        }
        .onAppear {
            ILOG("ContentView: Appeared")
        }
    }
}
