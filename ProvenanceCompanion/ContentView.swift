import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryTabView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            PeripheralsTabView()
                .tabItem {
                    Label("Peripherals", systemImage: "gamecontroller")
                }

            NavigationStack {
                VirtualControllerTabView()
            }
            .tabItem {
                Label("Controller", systemImage: "iphone.radiowaves.left.and.right")
            }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
