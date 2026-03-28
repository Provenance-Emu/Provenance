import SwiftUI
import StoreKit

/// Full-screen driver pack store sheet.
struct DriverStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeManager = DriverStoreManager()

    var body: some View {
        NavigationStack {
            Group {
                if storeManager.isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if storeManager.products.isEmpty {
                    ContentUnavailableView(
                        "Store Unavailable",
                        systemImage: "exclamationmark.icloud",
                        description: Text("Could not connect to the App Store. Check your connection and try again.")
                    )
                } else {
                    productList
                }
            }
            .navigationTitle("Driver Store")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task { await storeManager.restorePurchases() }
                    }
                }
            }
            .alert("Purchase Error", isPresented: Binding(
                get: { storeManager.purchaseError != nil },
                set: { if !$0 { storeManager.purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storeManager.purchaseError ?? "")
            }
        }
        .task { await storeManager.loadProducts() }
    }

    // MARK: - Product List

    private var productList: some View {
        ScrollView {
            VStack(spacing: 0) {
                reusabilityBanner
                    .padding()

                LazyVStack(spacing: 12) {
                    ForEach(storeManager.products) { product in
                        DriverProductCard(product: product) {
                            Task { await storeManager.purchase(product) }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    // MARK: - Reusability Banner

    private var reusabilityBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text("Works System-Wide")
                    .font(.headline)
                Text("Purchased drivers activate at the OS level — every emulator and game on your iPad benefits, not just Provenance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Product Card

private struct DriverProductCard: View {
    let product: DriverStoreProduct
    let onPurchase: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: product.id.systemImageName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.id.displayName)
                    .font(.headline)
                Text(product.id.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if product.isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button(product.displayPrice, action: onPurchase)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DriverStoreView()
}
