import SwiftUI
import PVLogging

/// A loading view to display while the Delta Skin is loading
struct DeltaSkinLoadingView: View {
    @State private var isAnimating = false
    let systemName: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Loading \(systemName) Skin...")
                .font(.headline)
                .foregroundColor(.white)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Please wait...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
        )
        .shadow(radius: 10)
        .onAppear {
            isAnimating = true
        }
    }
}
