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
                    ProgressView(String(localized: "store.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if storeManager.products.isEmpty {
                    ContentUnavailableView(
                        String(localized: "store.empty.title"),
                        systemImage: "exclamationmark.icloud",
                        description: Text("store.empty.description")
                    )
                } else {
                    productList
                }
            }
            .navigationTitle(String(localized: "store.nav_title"))
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "store.done_button")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "store.restore_button")) {
                        Task { await storeManager.restorePurchases() }
                    }
                }
            }
            .alert(String(localized: "store.error.purchase_failed_title"), isPresented: Binding(
                get: { storeManager.purchaseError != nil },
                set: { if !$0 { storeManager.purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: storeManager.purchaseError ?? "")
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
                Text("store.reusability.title")
                    .font(.headline)
                Text("store.reusability.description")
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
                Text(verbatim: product.id.displayName)
                    .font(.headline)
                Text(verbatim: product.id.localizedDescription)
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
