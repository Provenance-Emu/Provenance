import SwiftUI
import StoreKit

/// Entry point for the Virtual Controller tab in Provenance Companion.
///
/// Shows a paywall if the user has not purchased the virtual-controller IAP,
/// then presents ``VirtualControllerView`` once unlocked.
struct VirtualControllerTabView: View {
    @State private var storeManager = DriverStoreManager()
    @State private var showingStore = false

    var body: some View {
        Group {
            if storeManager.isPurchased(id: .virtualController) {
                VirtualControllerView()
            } else {
                lockedView
            }
        }
        .navigationTitle("Virtual Controller")
        .task { await storeManager.loadProducts() }
        .sheet(isPresented: $showingStore) {
            DriverStoreView()
                .environment(storeManager)
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.rectangle.on.rectangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Virtual Controller")
                    .font(.title2.bold())
                Text("Turn your iPhone or iPad into a wireless DSU controller. Works with Cemu, Yuzu, Dolphin, and any app that supports the CemuHook DSU protocol.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "gamecontroller.fill",   text: "Use Delta skins as your controller layout")
                featureRow(icon: "wifi",                  text: "Streams over Wi-Fi via DSU / CemuHook protocol")
                featureRow(icon: "apps.iphone",           text: "Works with any DSU-compatible emulator on your network")
                featureRow(icon: "applewatch",            text: "Pairs with the main Provenance app's skin library")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Button("Unlock Virtual Controller") {
                showingStore = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.accent)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        VirtualControllerTabView()
    }
}
