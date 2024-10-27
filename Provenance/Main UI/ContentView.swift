import SwiftUI
import PVLogging

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate

    var body: some View {
        content
            .onAppear {
                ILOG("ContentView: Appeared")
                appDelegate.appState = appState
            }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.bootupStateManager.currentState {
        case .completed:
            MainView(appDelegate: appDelegate)
        case .error(let error):
            ErrorView(error: error, retryAction: {
                appState.startBootupSequence()
            })
        default:
            BootupView()
        }
    }
}
