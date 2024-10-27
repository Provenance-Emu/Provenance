import SwiftUI
import PVLogging
import PVSwiftUI
import PVUIBase

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    let appDelegate: PVAppDelegate
    
    var body: some View {
        Group {
            switch appState.bootupStateManager.currentState {
            case .completed:
                ZStack {
                    MainView(appDelegate: appDelegate)
                    
//                    FirstResponderViewControllerWrapper()
//                        .edgesIgnoringSafeArea(.all)
                }
            case .error(let error):
                ErrorView(error: error) {
                    appState.startBootupSequence()
                }
            default:
                BootupView()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            ILOG("ContentView: Appeared")
        }
    }
}
