import SwiftUI
import StoreKit

/// Entry point for the Virtual Controller tab in Provenance Companion.
///
/// Shows a paywall if the user has not purchased the virtual-controller IAP,
/// then presents ``VirtualControllerView`` once unlocked.
struct VirtualControllerTabView: View {
    @Environment(DriverStoreManager.self) private var storeManager
    @State private var showingStore = false

    var body: some View {
        Group {
            if storeManager.isPurchased(id: .virtualController) {
                VirtualControllerView()
            } else {
                lockedView
            }
        }
        .navigationTitle(String(localized: "virtual_controller.nav_title"))
        .task { await storeManager.loadProducts() }
        .sheet(isPresented: $showingStore) {
            DriverStoreView()
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.rectangle.on.rectangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("virtual_controller.locked.title")
                    .font(.title2.bold())
                Text("virtual_controller.locked.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "gamecontroller.fill",   key: "virtual_controller.locked.feature.skins")
                featureRow(icon: "wifi",                  key: "virtual_controller.locked.feature.wifi")
                featureRow(icon: "apps.iphone",           key: "virtual_controller.locked.feature.emulators")
                featureRow(icon: "applewatch",            key: "virtual_controller.locked.feature.library")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Button(String(localized: "virtual_controller.locked.unlock_button")) {
                showingStore = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func featureRow(icon: String, key: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.accent)
            Text(key)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        VirtualControllerTabView()
    }
    .environment(DriverStoreManager())
}
