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
