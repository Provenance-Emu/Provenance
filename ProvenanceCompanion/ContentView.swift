import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryTabView()
                .tabItem {
                    Label(String(localized: "tab.library"), systemImage: "books.vertical")
                }

            CheatsTabView()
                .tabItem {
                    Label(String(localized: "tab.cheats"), systemImage: "doc.on.clipboard")
                }

            PeripheralsTabView()
                .tabItem {
                    Label(String(localized: "tab.peripherals"), systemImage: "gamecontroller")
                }

            NavigationStack {
                VirtualControllerTabView()
            }
            .tabItem {
                Label(String(localized: "tab.controller"), systemImage: "iphone.radiowaves.left.and.right")
            }

            SettingsTabView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(DriverStoreManager())
}
